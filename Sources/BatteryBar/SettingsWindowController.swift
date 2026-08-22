import AppKit

@MainActor
final class BatteryHealthCache {
    var snapshot: BatteryHealthSnapshot?
    var lastRefresh: Date?
    var refreshTask: Task<BatteryHealthSnapshot?, Never>?
}

enum BetterBatterySettingsPane: String, CaseIterable {
    case general
    case batteryHealth

    var title: String {
        switch self {
        case .general:
            "General"
        case .batteryHealth:
            "Battery Health"
        }
    }

    var symbolName: String {
        switch self {
        case .general:
            "gearshape"
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
    NSToolbarDelegate
{
    private static let contentSize = NSSize(width: 560, height: 390)
    static let batteryCycleSupportURL = URL(
        string: "https://support.apple.com/en-us/102888"
    )!

    var onClose: (() -> Void)?

    private let batteryHealthCache: BatteryHealthCache
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

    private lazy var generalView = makeGeneralView()
    private lazy var batteryHealthView = makeBatteryHealthView()
    private var healthRefreshInProgress = false

    init(batteryHealthCache: BatteryHealthCache) {
        self.batteryHealthCache = batteryHealthCache
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
        window?.contentView = pane == .general ? generalView : batteryHealthView
        window?.setContentSize(Self.contentSize)

        if pane == .general {
            refreshGeneralControls()
        } else {
            refreshBatteryHealthIfNeeded()
        }
    }

    private func makeGeneralView() -> NSView {
        let view = NSView()

        percentageOnlyCheckbox.font = .systemFont(ofSize: 14)
        hidePercentSymbolCheckbox.font = .systemFont(ofSize: 14)
        openAtLoginCheckbox.font = .systemFont(ofSize: 14)

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
                percentageStack,
                percentSymbolStack,
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

    private func makeBatteryHealthView() -> NSView {
        let view = NSView()

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
        item.action = pane == .general
            ? #selector(selectGeneralPane)
            : #selector(selectBatteryHealthPane)
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
