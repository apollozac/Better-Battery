import Foundation

enum AppPreferences {
    private static let percentageOnlyDefaultsKey = "ShowPercentageOnly"

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
}
