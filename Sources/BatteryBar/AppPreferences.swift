import Foundation

enum ChargingIconStyle: String, CaseIterable {
    case percentageFill
    case original

    var title: String {
        switch self {
        case .percentageFill:
            "Battery Level + Bolt"
        case .original:
            "Full Battery + Bolt"
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
    private static let hidesPercentSymbolDefaultsKey = "HidePercentSymbol"
    private static let chargingIconStyleDefaultsKey = "ChargingIconStyle"
    private static let percentagePositionDefaultsKey = "PercentagePosition"
    private static let appliedOpenAtLoginDefaultDefaultsKey =
        "AppliedOpenAtLoginDefault"

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

    static var hidesPercentSymbol: Bool {
        get {
            UserDefaults.standard.object(forKey: hidesPercentSymbolDefaultsKey)
                as? Bool ?? false
        }
        set {
            UserDefaults.standard.set(newValue, forKey: hidesPercentSymbolDefaultsKey)
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

    static var hasAppliedOpenAtLoginDefault: Bool {
        get {
            UserDefaults.standard.bool(
                forKey: appliedOpenAtLoginDefaultDefaultsKey
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: appliedOpenAtLoginDefaultDefaultsKey
            )
        }
    }
}
