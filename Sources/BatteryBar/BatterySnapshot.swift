import Foundation

struct BatterySnapshot: Equatable {
    let percentage: Int
    let isCharging: Bool
    let isConnectedToPower: Bool
    let isFullyCharged: Bool
    let isFinishingCharge: Bool
    let minutesRemaining: Int?
    let minutesToFull: Int?

    init(
        percentage: Int,
        isCharging: Bool,
        isConnectedToPower: Bool,
        isFullyCharged: Bool? = nil,
        isFinishingCharge: Bool = false,
        minutesRemaining: Int?,
        minutesToFull: Int? = nil
    ) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isConnectedToPower = isConnectedToPower
        self.isFullyCharged = isFullyCharged
            ?? (isConnectedToPower && !isCharging && percentage >= 100)
        self.isFinishingCharge = isFinishingCharge
        self.minutesRemaining = minutesRemaining
        self.minutesToFull = minutesToFull
    }

    var powerSourceDescription: String {
        isConnectedToPower ? "Power Adapter" : "Battery"
    }

    var stateDescription: String {
        if isFinishingCharge {
            return "Finishing Charge"
        }
        if isCharging {
            return "Charging"
        }
        if isFullyCharged {
            return "Fully Charged"
        }
        if isConnectedToPower {
            return "Power Adapter"
        }
        return "On Battery"
    }

    var timeDescription: String? {
        if isConnectedToPower, isCharging, let minutesToFull, minutesToFull > 0 {
            return "\(Self.formattedDuration(minutes: minutesToFull)) until full"
        }
        if isConnectedToPower, isFinishingCharge {
            return "Finishing Charge"
        }
        if isFullyCharged {
            return "Fully Charged"
        }

        guard !isConnectedToPower, let minutesRemaining, minutesRemaining > 0 else {
            return nil
        }

        return "\(Self.formattedDuration(minutes: minutesRemaining)) remaining"
    }

    private static func formattedDuration(minutes totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes) min"
        }
        if minutes == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(minutes) min"
    }

    static func percentage(current: Int, maximum: Int) -> Int? {
        guard maximum > 0 else {
            return nil
        }

        let value = Int((Double(current) / Double(maximum) * 100).rounded())
        return min(max(value, 0), 100)
    }
}
