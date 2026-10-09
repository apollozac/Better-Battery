import Foundation

enum BatteryDesign: String, CaseIterable {
    case modern
    case classic

    var title: String {
        switch self {
        case .modern:
            "Modern"
        case .classic:
            "Classic"
        }
    }
}

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
    private static let batteryDesignDefaultsKey = "BatteryDesign"
    private static let chargingIconStyleDefaultsKey = "ChargingIconStyle"
    private static let percentagePositionDefaultsKey = "PercentagePosition"
    private static let appliedOpenAtLoginDefaultDefaultsKey =
        "AppliedOpenAtLoginDefault"
    private static let dischargingNotificationThresholdsDefaultsKey =
        "DischargingNotificationThresholds"
    private static let chargingNotificationThresholdsDefaultsKey =
        "ChargingNotificationThresholds"
    private static let customDischargingNotificationEnabledDefaultsKey =
        "CustomDischargingNotificationEnabled"
    private static let customDischargingNotificationPercentageDefaultsKey =
        "CustomDischargingNotificationPercentage"
    private static let customChargingNotificationEnabledDefaultsKey =
        "CustomChargingNotificationEnabled"
    private static let customChargingNotificationPercentageDefaultsKey =
        "CustomChargingNotificationPercentage"

    static let dischargingNotificationPresets = [1, 5, 10, 20, 50, 80]
    static let chargingNotificationPresets = [5, 10, 20, 50, 80, 100]
    static let defaultDischargingNotificationThresholds: Set<Int> = [20]
    static let defaultChargingNotificationThresholds: Set<Int> = [80]

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

    static var batteryDesign: BatteryDesign {
        get {
            guard
                let rawValue = UserDefaults.standard.string(
                    forKey: batteryDesignDefaultsKey
                ),
                let design = BatteryDesign(rawValue: rawValue)
            else {
                return .modern
            }
            return design
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: batteryDesignDefaultsKey
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

    static var dischargingNotificationThresholds: Set<Int> {
        get {
            guard let values = UserDefaults.standard.array(
                forKey: dischargingNotificationThresholdsDefaultsKey
            ) as? [Int] else {
                return defaultDischargingNotificationThresholds
            }
            return Set(values).intersection(dischargingNotificationPresets)
        }
        set {
            UserDefaults.standard.set(
                newValue.intersection(dischargingNotificationPresets).sorted(),
                forKey: dischargingNotificationThresholdsDefaultsKey
            )
        }
    }

    static var chargingNotificationThresholds: Set<Int> {
        get {
            guard let values = UserDefaults.standard.array(
                forKey: chargingNotificationThresholdsDefaultsKey
            ) as? [Int] else {
                return defaultChargingNotificationThresholds
            }
            return Set(values).intersection(chargingNotificationPresets)
        }
        set {
            UserDefaults.standard.set(
                newValue.intersection(chargingNotificationPresets).sorted(),
                forKey: chargingNotificationThresholdsDefaultsKey
            )
        }
    }

    static var customDischargingNotificationEnabled: Bool {
        get {
            UserDefaults.standard.bool(
                forKey: customDischargingNotificationEnabledDefaultsKey
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: customDischargingNotificationEnabledDefaultsKey
            )
        }
    }

    static var customDischargingNotificationPercentage: Int {
        get {
            let value = UserDefaults.standard.integer(
                forKey: customDischargingNotificationPercentageDefaultsKey
            )
            return (1...100).contains(value) ? value : 30
        }
        set {
            UserDefaults.standard.set(
                min(max(newValue, 1), 100),
                forKey: customDischargingNotificationPercentageDefaultsKey
            )
        }
    }

    static var customChargingNotificationEnabled: Bool {
        get {
            UserDefaults.standard.bool(
                forKey: customChargingNotificationEnabledDefaultsKey
            )
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: customChargingNotificationEnabledDefaultsKey
            )
        }
    }

    static var customChargingNotificationPercentage: Int {
        get {
            let value = UserDefaults.standard.integer(
                forKey: customChargingNotificationPercentageDefaultsKey
            )
            return (1...100).contains(value) ? value : 90
        }
        set {
            UserDefaults.standard.set(
                min(max(newValue, 1), 100),
                forKey: customChargingNotificationPercentageDefaultsKey
            )
        }
    }

    static var allDischargingNotificationThresholds: Set<Int> {
        var thresholds = dischargingNotificationThresholds.union(additionalDischargingThresholds)
        if customDischargingNotificationEnabled {
            thresholds.insert(customDischargingNotificationPercentage)
        }
        return thresholds
    }

    static var allChargingNotificationThresholds: Set<Int> {
        var thresholds = chargingNotificationThresholds.union(additionalChargingThresholds)
        if customChargingNotificationEnabled {
            thresholds.insert(customChargingNotificationPercentage)
        }
        return thresholds
    }

    static var hasAnyNotificationThreshold: Bool {
        !allDischargingNotificationThresholds.isEmpty ||
            !allChargingNotificationThresholds.isEmpty
    }

    static func parseThresholds(_ text: String) -> Set<Int>? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let values = parts.compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        guard values.count == parts.count, values.allSatisfy({ (1...100).contains($0) }) else { return nil }
        return Set(values)
    }

    static var additionalDischargingThresholds: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: "AdditionalDischargingThresholds") as? [Int] ?? []).filter { (1...100).contains($0) } }
        set { UserDefaults.standard.set(newValue.filter { (1...100).contains($0) }.sorted(), forKey: "AdditionalDischargingThresholds") }
    }

    static var additionalChargingThresholds: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: "AdditionalChargingThresholds") as? [Int] ?? []).filter { (1...100).contains($0) } }
        set { UserDefaults.standard.set(newValue.filter { (1...100).contains($0) }.sorted(), forKey: "AdditionalChargingThresholds") }
    }
}
