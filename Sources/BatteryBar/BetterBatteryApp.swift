import AppKit
import Sparkle

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
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        LoginItemManager().applyEnabledDefaultIfNeeded()

        let controller = BatteryStatusController(
            updaterController: updaterController
        )
        controller.start()
        statusController = controller
    }
}
