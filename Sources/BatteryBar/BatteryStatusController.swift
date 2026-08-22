import AppKit
import IOKit.ps
import Sparkle

private func batteryPowerSourceDidChange(_ context: UnsafeMutableRawPointer?) {
    guard let context else {
        return
    }

    let controller = Unmanaged<BatteryStatusController>
        .fromOpaque(context)
        .takeUnretainedValue()

    DispatchQueue.main.async {
        controller.handlePowerSourceChange()
    }
}

private struct StatusPresentation: Equatable {
    let percentage: Int
    let isConnectedToPower: Bool
    let stateDescription: String
    let showsPercentageOnly: Bool
    let hidesPercentSymbol: Bool
    let chargingIconStyle: ChargingIconStyle
    let percentagePosition: PercentagePosition
}

@MainActor
final class InformationalMenuRowView: NSView {
    private static let horizontalInset: CGFloat = 14.5
    private static let rowHeight: CGFloat = 24

    private let label = NSTextField(labelWithString: "")

    var title: String {
        didSet {
            guard title != oldValue else {
                return
            }
            label.stringValue = title
            resizeToFit()
        }
    }

    init(title: String) {
        self.title = title
        super.init(frame: .zero)

        label.font = NSFont.menuFont(ofSize: 0)
        label.textColor = .labelColor
        label.stringValue = title
        label.lineBreakMode = .byClipping
        label.usesSingleLineMode = true
        addSubview(label)
        resizeToFit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func resizeToFit() {
        let font = label.font ?? NSFont.menuFont(ofSize: 0)
        // NSTextFieldCell adds horizontal drawing insets beyond the string's
        // typographic advance. Using only NSString.size clips the last glyph.
        let textSize = label.cell?.cellSize ??
            (title as NSString).size(withAttributes: [.font: font])
        frame.size = NSSize(
            width: ceil(textSize.width) + (Self.horizontalInset * 2),
            height: Self.rowHeight
        )
        label.frame = NSRect(
            x: Self.horizontalInset,
            y: floor((Self.rowHeight - ceil(textSize.height)) / 2),
            width: ceil(textSize.width),
            height: ceil(textSize.height)
        )
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: NSSize {
        frame.size
    }
}

@MainActor
final class BatteryStatusController: NSObject, NSMenuDelegate {
    static let statusItemAutosaveName = "BetterBatteryStatusItem"
    static let standardSafetyRefreshInterval: TimeInterval = 5 * 60
    static let fullyChargedSafetyRefreshInterval: TimeInterval = 15 * 60
    static let menuRefreshFreshnessInterval: TimeInterval = 5

    static let percentageFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
        weight: .regular
    )

    private let reader = BatteryReader()
    private let updaterController: SPUStandardUpdaterController?
    private let batteryHealthCache = BatteryHealthCache()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let powerSourceItem = NSMenuItem(
        title: "Reading Battery…",
        action: nil,
        keyEquivalent: ""
    )
    private let timeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let powerSourceRow = InformationalMenuRowView(title: "Reading Battery…")
    private let timeRow = InformationalMenuRowView(title: "")
    private lazy var settingsItem: NSMenuItem = {
        let item = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        item.target = self
        item.keyEquivalentModifierMask = .command
        Self.removeImages(from: item)
        return item
    }()
    private var timer: Timer?
    private var timerInterval: TimeInterval?
    private var powerSourceRunLoopSource: CFRunLoopSource?
    private var settingsWindowController: SettingsWindowController?
    private var lastStatusPresentation: StatusPresentation?
    private var isShowingUnavailableStatus = false
    private var lastSuccessfulRefreshUptime: TimeInterval?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
        super.init()
    }

    func start() {
        configureStatusItem()
        configurePowerSourceNotifications()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displayModeDidChange),
            name: AppPreferences.displayModeDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        refresh()
    }

    private func configurePowerSourceNotifications() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource(
            batteryPowerSourceDidChange,
            context
        )?.takeRetainedValue() else {
            return
        }

        powerSourceRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private func configureStatusItem() {
        statusItem.autosaveName = Self.statusItemAutosaveName

        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.imageHugsTitle = true
            button.alignment = .center
            button.font = Self.percentageFont
            button.cell?.wraps = false
            button.cell?.usesSingleLineMode = true
            button.cell?.lineBreakMode = .byClipping
        }

        Self.configureInformationalItem(powerSourceItem, with: powerSourceRow)
        Self.configureInformationalItem(timeItem, with: timeRow)
        timeItem.isHidden = true

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        menu.addItem(powerSourceItem)
        menu.addItem(timeItem)
        menu.addItem(.separator())
        if let updaterController {
            let updateItem = NSMenuItem(
                title: "Check for Updates…",
                action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
                keyEquivalent: ""
            )
            updateItem.target = updaterController
            menu.addItem(updateItem)
        }
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    static func configureInformationalItem(
        _ menuItem: NSMenuItem,
        with row: InformationalMenuRowView
    ) {
        menuItem.isEnabled = false
        menuItem.view = row
    }

    static func updateInformationalItem(
        _ menuItem: NSMenuItem,
        row: InformationalMenuRowView,
        title: String
    ) {
        if menuItem.title != title {
            menuItem.title = title
        }
        if row.title != title {
            row.title = title
        }
    }

    static func powerSourceTitle(snapshot: BatterySnapshot) -> String {
        "Power Source: \(snapshot.powerSourceDescription)"
    }

    nonisolated static func percentageTitle(
        percentage: Int,
        hidesPercentSymbol: Bool
    ) -> String {
        "\(percentage)\(hidesPercentSymbol ? "" : "%")"
    }

    static func safetyRefreshInterval(
        for snapshot: BatterySnapshot?
    ) -> TimeInterval {
        guard
            let snapshot,
            snapshot.isConnectedToPower,
            snapshot.isFullyCharged
        else {
            return standardSafetyRefreshInterval
        }
        return fullyChargedSafetyRefreshInterval
    }

    static func shouldRefreshOnMenuOpen(
        lastSuccessfulRefreshUptime: TimeInterval?,
        currentUptime: TimeInterval
    ) -> Bool {
        guard let lastSuccessfulRefreshUptime else {
            return true
        }
        return currentUptime - lastSuccessfulRefreshUptime
            >= menuRefreshFreshnessInterval
    }

    @objc private func refresh() {
        guard let snapshot = reader.currentSnapshot() else {
            updateSafetyRefreshTimer(for: nil)
            let title = "—"
            if !isShowingUnavailableStatus {
                let showsPercentageOnly = AppPreferences.showsPercentageOnly
                statusItem.button?.image = showsPercentageOnly
                    ? nil
                    : BatteryIconRenderer.image(
                        percentage: 0,
                        isConnectedToPower: false,
                        chargingIconStyle: AppPreferences.chargingIconStyle
                    )
                statusItem.button?.title = title
                statusItem.button?.toolTip = "Battery information unavailable"
                updateStatusItemLayout(
                    for: title,
                    showsPercentageOnly: showsPercentageOnly,
                    percentagePosition: AppPreferences.percentagePosition
                )
                lastStatusPresentation = nil
                isShowingUnavailableStatus = true
            }
            Self.updateInformationalItem(
                powerSourceItem,
                row: powerSourceRow,
                title: "Battery information unavailable"
            )
            timeItem.isHidden = true
            return
        }

        lastSuccessfulRefreshUptime = ProcessInfo.processInfo.systemUptime
        updateSafetyRefreshTimer(for: snapshot)

        let hidesPercentSymbol = AppPreferences.hidesPercentSymbol
        let title = Self.percentageTitle(
            percentage: snapshot.percentage,
            hidesPercentSymbol: hidesPercentSymbol
        )
        let presentation = StatusPresentation(
            percentage: snapshot.percentage,
            isConnectedToPower: snapshot.isConnectedToPower,
            stateDescription: snapshot.stateDescription,
            showsPercentageOnly: AppPreferences.showsPercentageOnly,
            hidesPercentSymbol: hidesPercentSymbol,
            chargingIconStyle: AppPreferences.chargingIconStyle,
            percentagePosition: AppPreferences.percentagePosition
        )
        if presentation != lastStatusPresentation || isShowingUnavailableStatus {
            statusItem.button?.image = presentation.showsPercentageOnly
                ? nil
                : BatteryIconRenderer.image(
                    percentage: presentation.percentage,
                    isConnectedToPower: presentation.isConnectedToPower,
                    chargingIconStyle: presentation.chargingIconStyle
                )
            statusItem.button?.title = title
            statusItem.button?.toolTip =
                "\(presentation.percentage)% — \(presentation.stateDescription)"
            updateStatusItemLayout(
                for: title,
                showsPercentageOnly: presentation.showsPercentageOnly,
                percentagePosition: presentation.percentagePosition
            )
            lastStatusPresentation = presentation
            isShowingUnavailableStatus = false
        }
        Self.updateInformationalItem(
            powerSourceItem,
            row: powerSourceRow,
            title: Self.powerSourceTitle(snapshot: snapshot)
        )
        if let timeDescription = snapshot.timeDescription {
            Self.updateInformationalItem(
                timeItem,
                row: timeRow,
                title: timeDescription
            )
            if timeItem.isHidden {
                timeItem.isHidden = false
            }
        } else {
            if !timeItem.isHidden {
                timeItem.isHidden = true
            }
        }
    }

    private func updateSafetyRefreshTimer(for snapshot: BatterySnapshot?) {
        let interval = Self.safetyRefreshInterval(for: snapshot)
        guard timerInterval != interval else {
            return
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(refresh),
            userInfo: nil,
            repeats: true
        )
        timer?.tolerance = interval * 0.1
        timerInterval = interval
    }

    private func updateStatusItemLayout(
        for title: String,
        showsPercentageOnly: Bool,
        percentagePosition: PercentagePosition
    ) {
        guard let button = statusItem.button else {
            return
        }

        button.font = Self.percentageFont
        if showsPercentageOnly {
            button.imagePosition = .noImage
            let font = button.font ?? Self.percentageFont
            let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
            statusItem.length = ceil(textWidth) + 2
        } else {
            button.imagePosition = percentagePosition == .rightOfBattery
                ? .imageLeading
                : .imageTrailing
            statusItem.length = NSStatusItem.variableLength
        }
    }

    func handlePowerSourceChange() {
        refresh()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if Self.shouldRefreshOnMenuOpen(
            lastSuccessfulRefreshUptime: lastSuccessfulRefreshUptime,
            currentUptime: ProcessInfo.processInfo.systemUptime
        ) {
            refresh()
        }
        Self.removeImages(from: settingsItem)
    }

    static func removeImages(from menuItem: NSMenuItem) {
        menuItem.preferredImageVisibility = .hidden
        menuItem.image = nil
        menuItem.onStateImage = nil
        menuItem.offStateImage = nil
        menuItem.mixedStateImage = nil
        menuItem.state = .off
    }

    @objc private func systemDidWake() {
        refresh()
    }

    @objc private func displayModeDidChange() {
        lastStatusPresentation = nil
        isShowingUnavailableStatus = false
        refresh()
    }

    @objc private func openSettings() {
        let controller: SettingsWindowController
        if let existingController = settingsWindowController {
            controller = existingController
        } else {
            controller = SettingsWindowController(
                batteryHealthCache: batteryHealthCache
            )
            controller.onClose = { [weak self, weak controller] in
                guard self?.settingsWindowController === controller else {
                    return
                }
                self?.settingsWindowController = nil
            }
            settingsWindowController = controller
        }
        controller.showGeneralSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
