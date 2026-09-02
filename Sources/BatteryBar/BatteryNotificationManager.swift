import AppKit
@preconcurrency import UserNotifications

enum BatteryNotificationDirection: Equatable {
    case charging
    case discharging
}

struct BatteryNotificationEvent: Equatable {
    let threshold: Int
    let percentage: Int
    let direction: BatteryNotificationDirection
}

enum BatteryNotificationPolicy {
    static func event(
        previousPercentage: Int,
        snapshot: BatterySnapshot,
        chargingThresholds: Set<Int>,
        dischargingThresholds: Set<Int>
    ) -> BatteryNotificationEvent? {
        let currentPercentage = snapshot.percentage
        guard currentPercentage != previousPercentage else {
            return nil
        }

        if currentPercentage > previousPercentage,
           snapshot.isConnectedToPower
        {
            let threshold = chargingThresholds
                .filter {
                    previousPercentage < $0 && currentPercentage >= $0
                }
                .max()
            return threshold.map {
                BatteryNotificationEvent(
                    threshold: $0,
                    percentage: currentPercentage,
                    direction: .charging
                )
            }
        }

        if currentPercentage < previousPercentage,
           !snapshot.isConnectedToPower
        {
            let threshold = dischargingThresholds
                .filter {
                    previousPercentage > $0 && currentPercentage <= $0
                }
                .min()
            return threshold.map {
                BatteryNotificationEvent(
                    threshold: $0,
                    percentage: currentPercentage,
                    direction: .discharging
                )
            }
        }

        return nil
    }

    static func title(for event: BatteryNotificationEvent) -> String {
        if event.threshold == 100 && event.direction == .charging {
            return "Battery Fully Charged"
        }
        if event.direction == .discharging {
            return "\(event.percentage)% Battery Remaining"
        }
        return "Battery Reached \(event.percentage)%"
    }

    static func body(for event: BatteryNotificationEvent) -> String {
        switch event.direction {
        case .charging:
            return "Your Mac is connected to power."
        case .discharging:
            return "Your Mac is running on battery power."
        }
    }
}

@MainActor
final class BatteryNotificationManager: NSObject,
    UNUserNotificationCenterDelegate
{
    private let center: UNUserNotificationCenter
    private var previousPercentage: Int?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    func start() {
        center.delegate = self
    }

    func process(snapshot: BatterySnapshot) {
        defer {
            previousPercentage = snapshot.percentage
        }
        guard
            let previousPercentage,
            let event = BatteryNotificationPolicy.event(
                previousPercentage: previousPercentage,
                snapshot: snapshot,
                chargingThresholds:
                    AppPreferences.allChargingNotificationThresholds,
                dischargingThresholds:
                    AppPreferences.allDischargingNotificationThresholds
            )
        else {
            return
        }

        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized ||
                    settings.authorizationStatus == .provisional
            else {
                return
            }
            Task { @MainActor [weak self] in
                self?.deliver(event)
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) {
            granted,
            _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func authorizationStatus(
        completion: @escaping (UNAuthorizationStatus) -> Void
    ) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    private func deliver(_ event: BatteryNotificationEvent) {
        let content = UNMutableNotificationContent()
        content.title = BatteryNotificationPolicy.title(for: event)
        content.body = BatteryNotificationPolicy.body(for: event)
        content.sound = .default

        let direction = event.direction == .charging ? "charging" : "discharging"
        let request = UNNotificationRequest(
            identifier: "battery-\(direction)-\(event.threshold)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
