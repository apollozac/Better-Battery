import AppKit

@MainActor
final class BatteryHealthCache {
    var snapshot: BatteryHealthSnapshot?
    var lastRefresh: Date?
    var refreshTask: Task<BatteryHealthSnapshot?, Never>?
}

enum BetterBatterySettingsPane: String, CaseIterable {
    case general
    case notifications
    case batteryHealth

    var title: String {
        switch self {
        case .general:
            "General"
        case .notifications:
            "Notifications"
        case .batteryHealth:
            "Battery Health"
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            "gearshape"
        case .notifications:
            "bell"
        case .batteryHealth:
            "battery.100percent"
        }
    }

    var toolbarIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier("BetterBatterySettings.\(rawValue)")
    }
}

@MainActor
final class SettingsWindowController:
    NSWindowController,
    NSWindowDelegate,
    NSToolbarDelegate,
    NSTextFieldDelegate
{
    private static let contentSize = NSSize(width: 560, height: 465)
    static let batteryCycleSupportURL = URL(
        string: "https://support.apple.com/en-us/102888"
    )!
    static let systemBatteryGuidance =
        "Hide Apple’s battery by Command-dragging it out of the menu bar, " +
        "or unchecking Battery in System Settings › Menu Bar."

    var onClose: (() -> Void)?

    private let batteryHealthCache: BatteryHealthCache
    private let notificationManager: BatteryNotificationManager
    private let batteryReader = BatteryReader()
    private let loginItemManager = LoginItemManager()
    private let percentageOnlyCheckbox = NSButton(
        checkboxWithTitle: "Show Percentage Only",
        target: nil,
        action: nil
    )
    private let hidePercentSymbolCheckbox = NSButton(
        checkboxWithTitle: "Hide Percent Symbol",
        target: nil,
        action: nil
    )
    private let openAtLoginCheckbox = NSButton(
        checkboxWithTitle: "Open at Login",
        target: nil,
        action: nil
    )
    private let chargingIconStylePopUp = NSPopUpButton(
        frame: .zero,
        pullsDown: false
    )
    private let batteryDesignPopUp = NSPopUpButton(
        frame: .zero,
        pullsDown: false
    )
    private let percentagePositionPopUp = NSPopUpButton(
        frame: .zero,
        pullsDown: false
    )
    private let loginDetailLabel = SettingsWindowController.makeDetailLabel("")
    private let percentSymbolDetailLabel =
        SettingsWindowController.makeDetailLabel("")
    private let conditionValueLabel = SettingsWindowController.makeValueLabel()
    private let capacityValueLabel = SettingsWindowController.makeValueLabel()
    private let cycleCountValueLabel = SettingsWindowController.makeValueLabel()
    private var dischargingNotificationThresholdCheckboxes: [Int: NSButton] = [:]
    private var chargingNotificationThresholdCheckboxes: [Int: NSButton] = [:]
    private let customDischargingNotificationCheckbox = NSButton(
        checkboxWithTitle: "Custom",
        target: nil,
        action: nil
    )
    private let customDischargingNotificationField = NSTextField(string: "30")
    private let customDischargingNotificationStepper = NSStepper()
    private let customChargingNotificationCheckbox = NSButton(
        checkboxWithTitle: "Custom",
        target: nil,
        action: nil
    )
    private let customChargingNotificationField = NSTextField(string: "90")
    private let customChargingNotificationStepper = NSStepper()
    private let notificationStatusLabel =
        SettingsWindowController.makeDetailLabel("")

    private lazy var generalView = makeGeneralView()
    private lazy var notificationsView = makeNotificationsView()
    private lazy var batteryHealthView = makeBatteryHealthView()
    private var healthRefreshInProgress = false

    init(
        batteryHealthCache: BatteryHealthCache,
        notificationManager: BatteryNotificationManager
    ) {
        self.batteryHealthCache = batteryHealthCache
        self.notificationManager = notificationManager
        let window = NSWindow(
            contentRect: NSRect(
                origin: .zero,
                size: Self.contentSize
            ),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = BetterBatterySettingsPane.general.title
        window.toolbarStyle = .preference
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()
        window.setFrameAutosaveName("BetterBatterySettingsWindow")

        super.init(window: window)
        window.delegate = self

        let toolbar = NSToolbar(identifier: "BetterBatterySettingsToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = false
        toolbar.autosavesConfiguration = false
        toolbar.displayMode = .iconAndLabel
        toolbar.selectedItemIdentifier =
            BetterBatterySettingsPane.general.toolbarIdentifier
        window.toolbar = toolbar

        percentageOnlyCheckbox.target = self
        percentageOnlyCheckbox.action = #selector(togglePercentageOnly)
        hidePercentSymbolCheckbox.target = self
        hidePercentSymbolCheckbox.action = #selector(togglePercentSymbol)
        batteryDesignPopUp.addItems(
            withTitles: BatteryDesign.allCases.map(\.title)
        )
        batteryDesignPopUp.target = self
        batteryDesignPopUp.action = #selector(changeBatteryDesign)
        chargingIconStylePopUp.addItems(
            withTitles: ChargingIconStyle.allCases.map(\.title)
        )
        chargingIconStylePopUp.target = self
        chargingIconStylePopUp.action = #selector(changeChargingIconStyle)
        percentagePositionPopUp.addItems(
            withTitles: PercentagePosition.allCases.map(\.title)
        )
        percentagePositionPopUp.target = self
        percentagePositionPopUp.action = #selector(changePercentagePosition)
        openAtLoginCheckbox.target = self
        openAtLoginCheckbox.action = #selector(toggleOpenAtLogin)
        customDischargingNotificationCheckbox.target = self
        customDischargingNotificationCheckbox.action =
            #selector(toggleCustomDischargingNotification)
        customDischargingNotificationField.delegate = self
        customDischargingNotificationField.target = self
        customDischargingNotificationField.action =
            #selector(changeCustomDischargingNotification)
        customDischargingNotificationStepper.target = self
        customDischargingNotificationStepper.action =
            #selector(stepCustomDischargingNotification)
        customChargingNotificationCheckbox.target = self
        customChargingNotificationCheckbox.action =
            #selector(toggleCustomChargingNotification)
        customChargingNotificationField.delegate = self
        customChargingNotificationField.target = self
        customChargingNotificationField.action =
            #selector(changeCustomChargingNotification)
        customChargingNotificationStepper.target = self
        customChargingNotificationStepper.action =
            #selector(stepCustomChargingNotification)

        selectPane(.general)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func showGeneralSettings() {
        selectPane(.general)
        refreshGeneralControls()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }

    private func selectPane(_ pane: BetterBatterySettingsPane) {
        window?.title = pane.title
        window?.toolbar?.selectedItemIdentifier = pane.toolbarIdentifier
        switch pane {
        case .general:
            window?.contentView = generalView
        case .notifications:
            window?.contentView = notificationsView
        case .batteryHealth:
            window?.contentView = batteryHealthView
        }
        window?.setContentSize(Self.contentSize)

        switch pane {
        case .general:
            refreshGeneralControls()
        case .notifications:
            refreshNotificationControls()
        case .batteryHealth:
            refreshBatteryHealthIfNeeded()
        }
    }

    private func makeGeneralView() -> NSView {
        let view = NSView()

        percentageOnlyCheckbox.font = .systemFont(ofSize: 14)
        hidePercentSymbolCheckbox.font = .systemFont(ofSize: 14)
        openAtLoginCheckbox.font = .systemFont(ofSize: 14)

        let systemBatteryGuidance = Self.makeDetailLabel(
            Self.systemBatteryGuidance
        )
        let percentageDetail = Self.makeDetailLabel(
            "Show the percentage without Better Battery’s battery icon."
        )

        let percentageStack = Self.makeControlStack(
            control: percentageOnlyCheckbox,
            detail: percentageDetail
        )
        let percentSymbolStack = Self.makeControlStack(
            control: hidePercentSymbolCheckbox,
            detail: percentSymbolDetailLabel
        )
        let batteryDesignLabel = NSTextField(labelWithString: "Battery Design")
        batteryDesignLabel.font = .systemFont(ofSize: 14)
        let batteryDesignControl = NSStackView(
            views: [batteryDesignLabel, batteryDesignPopUp]
        )
        batteryDesignControl.orientation = .horizontal
        batteryDesignControl.alignment = .centerY
        batteryDesignControl.spacing = 10
        let batteryDesignDetail = Self.makeDetailLabel(
            "Modern uses the filled macOS 27 design. Classic uses the outlined battery."
        )
        let batteryDesignStack = Self.makeControlStack(
            control: batteryDesignControl,
            detail: batteryDesignDetail
        )
        let chargingIconLabel = NSTextField(labelWithString: "Charging Icon")
        chargingIconLabel.font = .systemFont(ofSize: 14)
        let chargingIconControl = NSStackView(
            views: [chargingIconLabel, chargingIconStylePopUp]
        )
        chargingIconControl.orientation = .horizontal
        chargingIconControl.alignment = .centerY
        chargingIconControl.spacing = 10
        let chargingIconDetail = Self.makeDetailLabel(
            "Battery Level reflects the current charge. Full Battery always appears filled."
        )
        let chargingIconStack = Self.makeControlStack(
            control: chargingIconControl,
            detail: chargingIconDetail
        )
        let percentagePositionLabel = NSTextField(
            labelWithString: "Percentage Position"
        )
        percentagePositionLabel.font = .systemFont(ofSize: 14)
        let percentagePositionControl = NSStackView(
            views: [percentagePositionLabel, percentagePositionPopUp]
        )
        percentagePositionControl.orientation = .horizontal
        percentagePositionControl.alignment = .centerY
        percentagePositionControl.spacing = 10
        let percentagePositionDetail = Self.makeDetailLabel(
            "Choose which side of the battery icon displays the percentage."
        )
        let percentagePositionStack = Self.makeControlStack(
            control: percentagePositionControl,
            detail: percentagePositionDetail
        )
        let loginStack = Self.makeControlStack(
            control: openAtLoginCheckbox,
            detail: loginDetailLabel
        )

        let stack = NSStackView(
            views: [
                systemBatteryGuidance,
                percentageStack,
                percentSymbolStack,
                batteryDesignStack,
                chargingIconStack,
                percentagePositionStack,
                loginStack
            ]
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -48
            ),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 36)
        ])

        return view
    }

    private func makeNotificationsView() -> NSView {
        let view = NSView()

        let dischargingHeading = NSTextField(
            labelWithString: "Battery Draining"
        )
        dischargingHeading.font = .systemFont(ofSize: 14, weight: .medium)
        let dischargingButtons =
            AppPreferences.standardNotificationThresholds.map {
                threshold -> NSButton in
                let button = NSButton(
                    checkboxWithTitle: "\(threshold)%",
                    target: self,
                    action: #selector(toggleDischargingNotificationThreshold(_:))
                )
                button.font = .systemFont(ofSize: 14)
                button.tag = threshold
                dischargingNotificationThresholdCheckboxes[threshold] = button
                return button
            }
        let dischargingThresholdRow = NSStackView(views: dischargingButtons)
        dischargingThresholdRow.orientation = .horizontal
        dischargingThresholdRow.spacing = 10

        let chargingHeading = NSTextField(
            labelWithString: "Battery Charging"
        )
        chargingHeading.font = .systemFont(ofSize: 14, weight: .medium)
        let chargingButtons = AppPreferences.standardNotificationThresholds.map {
            threshold -> NSButton in
            let button = NSButton(
                checkboxWithTitle: "\(threshold)%",
                target: self,
                action: #selector(toggleChargingNotificationThreshold(_:))
            )
            button.font = .systemFont(ofSize: 14)
            button.tag = threshold
            chargingNotificationThresholdCheckboxes[threshold] = button
            return button
        }
        let chargingThresholdRow = NSStackView(views: chargingButtons)
        chargingThresholdRow.orientation = .horizontal
        chargingThresholdRow.spacing = 10

        let dischargingCustomRow = makeCustomNotificationRow(
            checkbox: customDischargingNotificationCheckbox,
            field: customDischargingNotificationField,
            stepper: customDischargingNotificationStepper
        )
        let chargingCustomRow = makeCustomNotificationRow(
            checkbox: customChargingNotificationCheckbox,
            field: customChargingNotificationField,
            stepper: customChargingNotificationStepper
        )

        let behaviorDetail = Self.makeDetailLabel(
            "Draining alerts fire only as the battery level falls. Charging alerts fire only as it rises."
        )

        let stack = NSStackView(
            views: [
                dischargingHeading,
                dischargingThresholdRow,
                dischargingCustomRow,
                chargingHeading,
                chargingThresholdRow,
                chargingCustomRow,
                behaviorDetail,
                notificationStatusLabel
            ]
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.setCustomSpacing(10, after: dischargingHeading)
        stack.setCustomSpacing(8, after: dischargingThresholdRow)
        stack.setCustomSpacing(24, after: dischargingCustomRow)
        stack.setCustomSpacing(10, after: chargingHeading)
        stack.setCustomSpacing(8, after: chargingThresholdRow)
        stack.setCustomSpacing(24, after: chargingCustomRow)
        stack.setCustomSpacing(14, after: behaviorDetail)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            stack.trailingAnchor.constraint(
                lessThanOrEqualTo: view.trailingAnchor,
                constant: -48
            ),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 36)
        ])

        return view
    }

    private func makeCustomNotificationRow(
        checkbox: NSButton,
        field: NSTextField,
        stepper: NSStepper
    ) -> NSStackView {
        checkbox.font = .systemFont(ofSize: 14)
        field.alignment = .right
        field.font = .systemFont(ofSize: 14)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 48).isActive = true
        let numberFormatter = NumberFormatter()
        numberFormatter.allowsFloats = false
        numberFormatter.minimum = 1
        numberFormatter.maximum = 100
        field.formatter = numberFormatter

        stepper.minValue = 1
        stepper.maxValue = 100
        stepper.increment = 1
        stepper.valueWraps = false
        let percentLabel = NSTextField(labelWithString: "%")
        percentLabel.font = .systemFont(ofSize: 14)
        let row = NSStackView(
            views: [checkbox, field, stepper, percentLabel]
        )
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        return row
    }

    private func makeBatteryHealthView() -> NSView {
        let view = NSView()

#if APP_STORE
        let grid = NSGridView(views: [
            [
                Self.makeRowLabel("Cycle Count"),
                cycleCountValueLabel
            ]
        ])
#else
        let grid = NSGridView(views: [
            [
                Self.makeRowLabel("Condition"),
                conditionValueLabel
            ],
            [
                Self.makeRowLabel("Maximum Capacity"),
                capacityValueLabel
            ],
            [
                Self.makeRowLabel("Cycle Count"),
                cycleCountValueLabel
            ]
        ])
#endif
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.columnSpacing = 28
        grid.rowSpacing = 18
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        let supportLink = NSButton(
            title: "Learn about battery cycle counts…",
            target: self,
            action: #selector(openBatteryCycleSupport)
        )
        supportLink.translatesAutoresizingMaskIntoConstraints = false
        supportLink.isBordered = false
        supportLink.focusRingType = .none
        supportLink.attributedTitle = NSAttributedString(
            string: supportLink.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        supportLink.toolTip = Self.batteryCycleSupportURL.absoluteString

        view.addSubview(grid)
        view.addSubview(supportLink)

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 70),
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            supportLink.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            supportLink.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 30)
        ])

        applyBatteryHealth(nil, isLoading: true)
        return view
    }

    private func refreshGeneralControls() {
        percentSymbolDetailLabel.stringValue = Self.percentSymbolDetail(
            percentage: batteryReader.currentSnapshot()?.percentage
        )
        percentageOnlyCheckbox.state =
            AppPreferences.showsPercentageOnly ? .on : .off
        hidePercentSymbolCheckbox.state =
            AppPreferences.hidesPercentSymbol ? .on : .off
        batteryDesignPopUp.selectItem(
            at: BatteryDesign.allCases.firstIndex(
                of: AppPreferences.batteryDesign
            ) ?? 0
        )
        chargingIconStylePopUp.selectItem(
            at: ChargingIconStyle.allCases.firstIndex(
                of: AppPreferences.chargingIconStyle
            ) ?? 0
        )
        percentagePositionPopUp.selectItem(
            at: PercentagePosition.allCases.firstIndex(
                of: AppPreferences.percentagePosition
            ) ?? 0
        )

        let presentation = loginItemManager.presentation
        switch presentation.indicator {
        case .off:
            openAtLoginCheckbox.state = .off
            openAtLoginCheckbox.isEnabled = true
            loginDetailLabel.stringValue =
                "Automatically open Better Battery when you log in."
        case .on:
            openAtLoginCheckbox.state = .on
            openAtLoginCheckbox.isEnabled = true
            loginDetailLabel.stringValue =
                "Better Battery will open automatically when you log in."
        case .approvalRequired:
            openAtLoginCheckbox.state = .mixed
            openAtLoginCheckbox.isEnabled = true
            loginDetailLabel.stringValue =
                "Approval is required in System Settings."
        case .unavailable:
            openAtLoginCheckbox.state = .off
            openAtLoginCheckbox.isEnabled = false
            loginDetailLabel.stringValue =
                "Open at Login is unavailable for this copy of the app."
        }
    }

    private func refreshNotificationControls() {
        let dischargingThresholds =
            AppPreferences.dischargingNotificationThresholds
        for (threshold, checkbox) in
            dischargingNotificationThresholdCheckboxes
        {
            checkbox.state = dischargingThresholds.contains(threshold) ? .on : .off
        }
        let chargingThresholds = AppPreferences.chargingNotificationThresholds
        for (threshold, checkbox) in chargingNotificationThresholdCheckboxes {
            checkbox.state = chargingThresholds.contains(threshold) ? .on : .off
        }

        refreshCustomNotificationControls(
            checkbox: customDischargingNotificationCheckbox,
            field: customDischargingNotificationField,
            stepper: customDischargingNotificationStepper,
            enabled: AppPreferences.customDischargingNotificationEnabled,
            percentage: AppPreferences.customDischargingNotificationPercentage
        )
        refreshCustomNotificationControls(
            checkbox: customChargingNotificationCheckbox,
            field: customChargingNotificationField,
            stepper: customChargingNotificationStepper,
            enabled: AppPreferences.customChargingNotificationEnabled,
            percentage: AppPreferences.customChargingNotificationPercentage
        )

        refreshNotificationAuthorizationStatus()
    }

    private func refreshCustomNotificationControls(
        checkbox: NSButton,
        field: NSTextField,
        stepper: NSStepper,
        enabled: Bool,
        percentage: Int
    ) {
        checkbox.state = enabled ? .on : .off
        field.integerValue = percentage
        stepper.integerValue = percentage
        field.isEnabled = enabled
        stepper.isEnabled = enabled
    }

    private func refreshNotificationAuthorizationStatus() {
        guard AppPreferences.hasAnyNotificationThreshold else {
            notificationStatusLabel.stringValue =
                "Notifications are off until you choose a battery level."
            return
        }

        notificationManager.authorizationStatus { [weak self] status in
            switch status {
            case .authorized, .provisional, .ephemeral:
                self?.notificationStatusLabel.stringValue =
                    "Notifications are enabled."
            case .denied:
                self?.notificationStatusLabel.stringValue =
                    "Notifications are disabled in System Settings."
            case .notDetermined:
                self?.notificationStatusLabel.stringValue =
                    "macOS will ask for permission to send notifications."
            @unknown default:
                self?.notificationStatusLabel.stringValue =
                    "Notification permission is unavailable."
            }
        }
    }

    private func requestNotificationAuthorizationIfNeeded() {
        guard AppPreferences.hasAnyNotificationThreshold else {
            refreshNotificationAuthorizationStatus()
            return
        }
        notificationManager.requestAuthorization { [weak self] _ in
            self?.refreshNotificationAuthorizationStatus()
        }
    }

    nonisolated static func percentSymbolDetail(percentage: Int?) -> String {
        guard let percentage else {
            return "Display the battery level without the percent symbol."
        }
        return "Display \(percentage) instead of \(percentage)%."
    }

    @objc private func togglePercentageOnly() {
        AppPreferences.showsPercentageOnly = percentageOnlyCheckbox.state == .on
    }

    @objc private func togglePercentSymbol() {
        AppPreferences.hidesPercentSymbol = hidePercentSymbolCheckbox.state == .on
    }

    @objc private func changeChargingIconStyle() {
        let selectedIndex = chargingIconStylePopUp.indexOfSelectedItem
        guard ChargingIconStyle.allCases.indices.contains(selectedIndex) else {
            return
        }
        AppPreferences.chargingIconStyle =
            ChargingIconStyle.allCases[selectedIndex]
    }

    @objc private func changeBatteryDesign() {
        let selectedIndex = batteryDesignPopUp.indexOfSelectedItem
        guard BatteryDesign.allCases.indices.contains(selectedIndex) else {
            return
        }
        AppPreferences.batteryDesign = BatteryDesign.allCases[selectedIndex]
    }

    @objc private func changePercentagePosition() {
        let selectedIndex = percentagePositionPopUp.indexOfSelectedItem
        guard PercentagePosition.allCases.indices.contains(selectedIndex) else {
            return
        }
        AppPreferences.percentagePosition =
            PercentagePosition.allCases[selectedIndex]
    }

    @objc private func toggleOpenAtLogin() {
        do {
            try loginItemManager.performToggle()
            refreshGeneralControls()
        } catch {
            refreshGeneralControls()
            loginDetailLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func toggleDischargingNotificationThreshold(
        _ sender: NSButton
    ) {
        let threshold = sender.tag
        guard AppPreferences.standardNotificationThresholds.contains(threshold)
        else {
            return
        }
        var thresholds = AppPreferences.dischargingNotificationThresholds
        if sender.state == .on {
            thresholds.insert(threshold)
        } else {
            thresholds.remove(threshold)
        }
        AppPreferences.dischargingNotificationThresholds = thresholds
        requestNotificationAuthorizationIfNeeded()
    }

    @objc private func toggleChargingNotificationThreshold(_ sender: NSButton) {
        let threshold = sender.tag
        guard AppPreferences.standardNotificationThresholds.contains(threshold)
        else {
            return
        }
        var thresholds = AppPreferences.chargingNotificationThresholds
        if sender.state == .on {
            thresholds.insert(threshold)
        } else {
            thresholds.remove(threshold)
        }
        AppPreferences.chargingNotificationThresholds = thresholds
        requestNotificationAuthorizationIfNeeded()
    }

    @objc private func toggleCustomDischargingNotification() {
        let enabled = customDischargingNotificationCheckbox.state == .on
        AppPreferences.customDischargingNotificationEnabled = enabled
        customDischargingNotificationField.isEnabled = enabled
        customDischargingNotificationStepper.isEnabled = enabled
        requestNotificationAuthorizationIfNeeded()
    }

    @objc private func toggleCustomChargingNotification() {
        let enabled = customChargingNotificationCheckbox.state == .on
        AppPreferences.customChargingNotificationEnabled = enabled
        customChargingNotificationField.isEnabled = enabled
        customChargingNotificationStepper.isEnabled = enabled
        requestNotificationAuthorizationIfNeeded()
    }

    @objc private func changeCustomDischargingNotification() {
        commitCustomDischargingNotificationPercentage()
    }

    @objc private func stepCustomDischargingNotification() {
        customDischargingNotificationField.integerValue =
            customDischargingNotificationStepper.integerValue
        commitCustomDischargingNotificationPercentage()
    }

    @objc private func changeCustomChargingNotification() {
        commitCustomChargingNotificationPercentage()
    }

    @objc private func stepCustomChargingNotification() {
        customChargingNotificationField.integerValue =
            customChargingNotificationStepper.integerValue
        commitCustomChargingNotificationPercentage()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        if field === customDischargingNotificationField {
            commitCustomDischargingNotificationPercentage()
        } else if field === customChargingNotificationField {
            commitCustomChargingNotificationPercentage()
        }
    }

    private func commitCustomDischargingNotificationPercentage() {
        let percentage = min(
            max(customDischargingNotificationField.integerValue, 1),
            100
        )
        customDischargingNotificationField.integerValue = percentage
        customDischargingNotificationStepper.integerValue = percentage
        AppPreferences.customDischargingNotificationPercentage = percentage
    }

    private func commitCustomChargingNotificationPercentage() {
        let percentage = min(
            max(customChargingNotificationField.integerValue, 1),
            100
        )
        customChargingNotificationField.integerValue = percentage
        customChargingNotificationStepper.integerValue = percentage
        AppPreferences.customChargingNotificationPercentage = percentage
    }

    @objc private func openBatteryCycleSupport() {
        NSWorkspace.shared.open(Self.batteryCycleSupportURL)
    }

    private func refreshBatteryHealthIfNeeded() {
        let cacheLifetime: TimeInterval = 60 * 60
        if
            let lastRefresh = batteryHealthCache.lastRefresh,
            Date().timeIntervalSince(lastRefresh) < cacheLifetime
        {
            applyBatteryHealth(
                batteryHealthCache.snapshot,
                isLoading: false
            )
            return
        }
        guard !healthRefreshInProgress else {
            return
        }

        healthRefreshInProgress = true
        applyBatteryHealth(nil, isLoading: true)

        let refreshTask: Task<BatteryHealthSnapshot?, Never>
        if let existingTask = batteryHealthCache.refreshTask {
            refreshTask = existingTask
        } else {
            let task = Task.detached(priority: .utility) {
                BatteryHealthReader().currentSnapshot()
            }
            batteryHealthCache.refreshTask = task
            refreshTask = task
        }

        Task { [weak self, batteryHealthCache] in
            let snapshot = await refreshTask.value
            batteryHealthCache.snapshot = snapshot
            batteryHealthCache.lastRefresh = Date()
            batteryHealthCache.refreshTask = nil
            self?.healthRefreshInProgress = false
            self?.applyBatteryHealth(snapshot, isLoading: false)
        }
    }

    private func applyBatteryHealth(
        _ snapshot: BatteryHealthSnapshot?,
        isLoading: Bool
    ) {
        if isLoading {
            conditionValueLabel.stringValue = "Loading…"
            capacityValueLabel.stringValue = "—"
            cycleCountValueLabel.stringValue = "—"
            return
        }

        conditionValueLabel.stringValue = snapshot?.condition ?? "Unavailable"
        capacityValueLabel.stringValue = snapshot?.maximumCapacity.map {
            "\($0)%"
        } ?? "—"
        cycleCountValueLabel.stringValue = snapshot?.cycleCount.map(String.init)
            ?? "—"
    }

    @objc private func selectGeneralPane() {
        selectPane(.general)
    }

    @objc private func selectNotificationsPane() {
        selectPane(.notifications)
    }

    @objc private func selectBatteryHealthPane() {
        selectPane(.batteryHealth)
    }

    func toolbarAllowedItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        BetterBatterySettingsPane.allCases.map(\.toolbarIdentifier)
    }

    func toolbarDefaultItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbarSelectableItemIdentifiers(
        _ toolbar: NSToolbar
    ) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard
            let pane = BetterBatterySettingsPane.allCases.first(where: {
                $0.toolbarIdentifier == itemIdentifier
            })
        else {
            return nil
        }

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.image = NSImage(
            systemSymbolName: pane.symbolName,
            accessibilityDescription: pane.title
        )
        item.target = self
        switch pane {
        case .general:
            item.action = #selector(selectGeneralPane)
        case .notifications:
            item.action = #selector(selectNotificationsPane)
        case .batteryHealth:
            item.action = #selector(selectBatteryHealthPane)
        }
        return item
    }

    private static func makeControlStack(
        control: NSView,
        detail: NSTextField
    ) -> NSStackView {
        let stack = NSStackView(views: [control, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }

    private static func makeDetailLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func makeRowLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func makeValueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "—")
        label.font = .systemFont(ofSize: 14)
        return label
    }
}
