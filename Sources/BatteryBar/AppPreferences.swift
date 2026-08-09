import Foundation

enum ChargingIconStyle: String, CaseIterable {
    case percentageFill
    case original

    var title: String {
        switch self {
        case .percentageFill:
            "Percentage Fill"
        case .original:
            "Original Charging Icon"
        }
    }
}

enum PercentagePosition: String, CaseIterable {
    case rightOfBattery
    case leftOfBattery

    var title: String {
        switch self {
        case .rightOfBattery:
            "Right of Battery"
        case .leftOfBattery:
            "Left of Battery"
        }
    }
}

enum AppPreferences {
    private static let percentageOnlyDefaultsKey = "ShowPercentageOnly"
    private static let chargingIconStyleDefaultsKey = "ChargingIconStyle"
    private static let percentagePositionDefaultsKey = "PercentagePosition"

    static let displayModeDidChangeNotification = Notification.Name(
        "BetterBatteryDisplayModeDidChange"
    )

    static var showsPercentageOnly: Bool {
        get {
            UserDefaults.standard.object(forKey: percentageOnlyDefaultsKey)
                as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: percentageOnlyDefaultsKey)
            NotificationCenter.default.post(
                name: displayModeDidChangeNotification,
                object: nil
            )
        }
    }

    static var chargingIconStyle: ChargingIconStyle {
        get {
            guard
                let rawValue = UserDefaults.standard.string(
                    forKey: chargingIconStyleDefaultsKey
                ),
                let style = ChargingIconStyle(rawValue: rawValue)
            else {
                return .percentageFill
            }
            return style
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: chargingIconStyleDefaultsKey
            )
            NotificationCenter.default.post(
                name: displayModeDidChangeNotification,
                object: nil
            )
        }
    }

    static var percentagePosition: PercentagePosition {
        get {
            guard
                let rawValue = UserDefaults.standard.string(
                    forKey: percentagePositionDefaultsKey
                ),
                let position = PercentagePosition(rawValue: rawValue)
            else {
                return .rightOfBattery
            }
            return position
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: percentagePositionDefaultsKey
            )
            NotificationCenter.default.post(
                name: displayModeDidChangeNotification,
                object: nil
            )
        }
    }
}
