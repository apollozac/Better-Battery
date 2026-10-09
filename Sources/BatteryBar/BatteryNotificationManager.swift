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
    private var tracker = BatteryNotificationTracker()

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    func start() {
        center.delegate = self
    }

    func process(snapshot: BatterySnapshot) {
        guard let event = tracker.process(
            snapshot: snapshot,
            chargingThresholds: AppPreferences.allChargingNotificationThresholds,
            dischargingThresholds: AppPreferences.allDischargingNotificationThresholds
        ) else { return }

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

    func sendTestNotification(completion: @escaping (String) -> Void) {
        requestAuthorization { [weak self] granted in
            guard granted, let self else {
                completion("Allow notifications in System Settings, then try again.")
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Better Battery Test"
            content.body = "Battery alerts are ready. Your selected levels will notify you here."
            content.sound = .default
            self.center.add(UNNotificationRequest(identifier: "battery-test", content: content, trigger: nil)) { error in
                let message = error.map { "Could not send notification: \($0.localizedDescription)" }
                    ?? "Test sent. Banner visibility and sound follow your macOS notification and Focus settings."
                DispatchQueue.main.async { completion(message) }
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

/// First readings and power-source changes establish a baseline. Subsequent
/// readings notify on every crossing, including thresholds crossed while asleep.
struct BatteryNotificationTracker {
    private var previous: BatterySnapshot?

    mutating func process(
        snapshot: BatterySnapshot,
        chargingThresholds: Set<Int>,
        dischargingThresholds: Set<Int>
    ) -> BatteryNotificationEvent? {
        defer { previous = snapshot }
        guard let previous else { return nil }
        guard previous.isConnectedToPower == snapshot.isConnectedToPower else {
            return nil
        }
        return BatteryNotificationPolicy.event(
            previousPercentage: previous.percentage, snapshot: snapshot,
            chargingThresholds: chargingThresholds, dischargingThresholds: dischargingThresholds
        )
    }
}
