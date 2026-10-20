@preconcurrency import UserNotifications

enum BatteryNotificationSound: String, CaseIterable, Sendable {
    case low = "BetterBattery-Low.wav"
    case target = "BetterBattery-Target.wav"
    case full = "BetterBattery-Full.wav"

    var displayName: String {
        switch self {
        case .low:
            return "Low Battery"
        case .target:
            return "Charge Target"
        case .full:
            return "Full Charge"
        }
    }

    /// Packaging places these original L1 recordings in the app's main
    /// Resources directory, where UserNotifications resolves named sounds.
    var sound: UNNotificationSound {
        UNNotificationSound(named: UNNotificationSoundName(rawValue: rawValue))
    }

    static func selection(for event: BatteryNotificationEvent) -> Self {
        if event.direction == .discharging {
            return .low
        }
        // Use the crossed threshold, not the current reading: a jump to 100%
        // crossing only an enabled 80% alert is still a charge-target alert.
        return event.threshold == 100 ? .full : .target
    }
}
