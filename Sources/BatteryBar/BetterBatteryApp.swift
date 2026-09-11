import AppKit
#if !APP_STORE
import Sparkle
#endif

@main
enum BetterBatteryApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: BatteryStatusController?
#if !APP_STORE
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
#endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
#if !APP_STORE
        LoginItemManager().applyEnabledDefaultIfNeeded()
#endif

#if APP_STORE
        let controller = BatteryStatusController()
#else
        let controller = BatteryStatusController(
            updaterController: updaterController
        )
#endif
        controller.start()
        statusController = controller
    }
}
