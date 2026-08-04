import AppKit
import ServiceManagement
import XCTest
@testable import BatteryBar

final class BatterySnapshotTests: XCTestCase {
    func testPercentageRoundsAndClamps() {
        XCTAssertEqual(BatterySnapshot.percentage(current: 49, maximum: 100), 49)
        XCTAssertEqual(BatterySnapshot.percentage(current: 1, maximum: 3), 33)
        XCTAssertEqual(BatterySnapshot.percentage(current: 120, maximum: 100), 100)
        XCTAssertEqual(BatterySnapshot.percentage(current: -10, maximum: 100), 0)
        XCTAssertNil(BatterySnapshot.percentage(current: 50, maximum: 0))
    }

    func testStateDescriptions() {
        let charging = BatterySnapshot(
            percentage: 80,
            isCharging: true,
            isConnectedToPower: true,
            minutesRemaining: nil,
            minutesToFull: 33
        )
        XCTAssertEqual(charging.stateDescription, "Charging")
        XCTAssertEqual(charging.powerSourceDescription, "Power Adapter")
        XCTAssertEqual(charging.timeDescription, "33 min until full")

        let roundedToOneHundredWhileCharging = BatterySnapshot(
            percentage: 100,
            isCharging: true,
            isConnectedToPower: true,
            isFullyCharged: false,
            minutesRemaining: nil,
            minutesToFull: 10
        )
        XCTAssertEqual(
            roundedToOneHundredWhileCharging.stateDescription,
            "Charging"
        )
        XCTAssertEqual(
            roundedToOneHundredWhileCharging.timeDescription,
            "10 min until full"
        )

        let finishingCharge = BatterySnapshot(
            percentage: 100,
            isCharging: true,
            isConnectedToPower: true,
            isFullyCharged: false,
            isFinishingCharge: true,
            minutesRemaining: nil
        )
        XCTAssertEqual(finishingCharge.stateDescription, "Finishing Charge")
        XCTAssertEqual(finishingCharge.timeDescription, "Finishing Charge")

        XCTAssertEqual(
            BatterySnapshot(
                percentage: 100,
                isCharging: false,
                isConnectedToPower: true,
                minutesRemaining: nil
            ).stateDescription,
            "Fully Charged"
        )
        XCTAssertEqual(
            BatterySnapshot(
                percentage: 75,
                isCharging: false,
                isConnectedToPower: false,
                minutesRemaining: 135
            ).powerSourceDescription,
            "Battery"
        )
        XCTAssertEqual(
            BatterySnapshot(
                percentage: 75,
                isCharging: false,
                isConnectedToPower: false,
                minutesRemaining: 135
            ).timeDescription,
            "2 hr 15 min remaining"
        )
    }

    func testBatteryIconUsesBoltWheneverConnectedToPower() {
        XCTAssertEqual(BatteryIconRenderer.symbolPointSize, 18)
        XCTAssertTrue(
            BatteryIconRenderer.showsPowerBolt(
                isConnectedToPower: true
            )
        )
        XCTAssertFalse(
            BatteryIconRenderer.showsPowerBolt(
                isConnectedToPower: false
            )
        )
        XCTAssertTrue(
            BatteryIconRenderer.showsPowerBolt(
                isConnectedToPower: true
            ),
            "A full battery still needs to indicate that external power is connected"
        )
        XCTAssertEqual(
            BatteryIconRenderer.symbolName(
                percentage: 38,
                showsPowerBolt: true
            ),
            "battery.100percent.bolt"
        )
        XCTAssertEqual(
            BatteryIconRenderer.symbolName(
                percentage: 12,
                showsPowerBolt: false
            ),
            "battery.0percent"
        )
        XCTAssertEqual(
            BatteryIconRenderer.symbolName(
                percentage: 13,
                showsPowerBolt: false
            ),
            "battery.25percent"
        )
        XCTAssertEqual(
            BatteryIconRenderer.symbolName(
                percentage: 38,
                showsPowerBolt: false
            ),
            "battery.50percent"
        )
        XCTAssertEqual(
            BatteryIconRenderer.symbolName(
                percentage: 63,
                showsPowerBolt: false
            ),
            "battery.75percent"
        )
        XCTAssertEqual(
            BatteryIconRenderer.symbolName(
                percentage: 88,
                showsPowerBolt: false
            ),
            "battery.100percent"
        )
    }

    func testBatteryHealthParserUsesSystemProfilerValues() {
        let data = Data(
            """
            {
              "SPPowerDataType": [
                {
                  "sppower_battery_health_info": {
                    "sppower_battery_cycle_count": 396,
                    "sppower_battery_health": "Good",
                    "sppower_battery_health_maximum_capacity": "94%"
                  }
                }
              ]
            }
            """.utf8
        )

        let snapshot = BatteryHealthReader.parse(data: data)
        XCTAssertEqual(
            snapshot,
            BatteryHealthSnapshot(
                condition: "Good",
                maximumCapacity: 94,
                cycleCount: 396
            )
        )
    }

    func testPublicTimeEstimateConvertsSecondsToMinutes() {
        XCTAssertEqual(BatteryReader.minutesRemaining(from: 5_400), 90)
        XCTAssertEqual(BatteryReader.minutesRemaining(from: 31), 1)
        XCTAssertNil(BatteryReader.minutesRemaining(from: 0))
        XCTAssertNil(BatteryReader.minutesRemaining(from: -1))
        XCTAssertNil(BatteryReader.minutesRemaining(from: -.infinity))
    }

    func testTimeEstimateFallbacksOnlyRunForRelevantPowerState() {
        var globalFallbackCalls = 0
        var registryFallbackCalls = 0

        let fullyCharged = BatteryReader.timeEstimates(
            isConnectedToPower: true,
            isCharging: false,
            isFullyCharged: true,
            isFinishingCharge: false,
            reportedMinutesRemaining: nil,
            reportedMinutesToFull: nil,
            globalMinutesRemaining: {
                globalFallbackCalls += 1
                return 120
            },
            registryMinutesToFull: {
                registryFallbackCalls += 1
                return 30
            }
        )
        XCTAssertNil(fullyCharged.remaining)
        XCTAssertNil(fullyCharged.toFull)
        XCTAssertEqual(globalFallbackCalls, 0)
        XCTAssertEqual(registryFallbackCalls, 0)

        let discharging = BatteryReader.timeEstimates(
            isConnectedToPower: false,
            isCharging: false,
            isFullyCharged: false,
            isFinishingCharge: false,
            reportedMinutesRemaining: nil,
            reportedMinutesToFull: nil,
            globalMinutesRemaining: {
                globalFallbackCalls += 1
                return 120
            },
            registryMinutesToFull: {
                registryFallbackCalls += 1
                return 30
            }
        )
        XCTAssertEqual(discharging.remaining, 120)
        XCTAssertNil(discharging.toFull)
        XCTAssertEqual(globalFallbackCalls, 1)
        XCTAssertEqual(registryFallbackCalls, 0)

        let charging = BatteryReader.timeEstimates(
            isConnectedToPower: true,
            isCharging: true,
            isFullyCharged: false,
            isFinishingCharge: false,
            reportedMinutesRemaining: nil,
            reportedMinutesToFull: nil,
            globalMinutesRemaining: {
                globalFallbackCalls += 1
                return 120
            },
            registryMinutesToFull: {
                registryFallbackCalls += 1
                return 30
            }
        )
        XCTAssertNil(charging.remaining)
        XCTAssertEqual(charging.toFull, 30)
        XCTAssertEqual(globalFallbackCalls, 1)
        XCTAssertEqual(registryFallbackCalls, 1)
    }

    @MainActor
    func testPowerSourceTitleDoesNotDisplayAdapterWattage() {
        let connected = BatterySnapshot(
            percentage: 75,
            isCharging: true,
            isConnectedToPower: true,
            minutesRemaining: nil
        )
        XCTAssertEqual(
            BatteryStatusController.powerSourceTitle(snapshot: connected),
            "Power Source: Power Adapter"
        )

        let battery = BatterySnapshot(
            percentage: 75,
            isCharging: false,
            isConnectedToPower: false,
            minutesRemaining: 120
        )
        XCTAssertEqual(
            BatteryStatusController.powerSourceTitle(snapshot: battery),
            "Power Source: Battery"
        )
    }

    @MainActor
    func testSafetyRefreshSlowsOnlyWhenFullyChargedOnPower() {
        let fullyCharged = BatterySnapshot(
            percentage: 100,
            isCharging: false,
            isConnectedToPower: true,
            isFullyCharged: true,
            minutesRemaining: nil
        )
        XCTAssertEqual(
            BatteryStatusController.safetyRefreshInterval(
                for: fullyCharged
            ),
            15 * 60
        )

        let charging = BatterySnapshot(
            percentage: 80,
            isCharging: true,
            isConnectedToPower: true,
            minutesRemaining: nil
        )
        XCTAssertEqual(
            BatteryStatusController.safetyRefreshInterval(for: charging),
            5 * 60
        )

        let discharging = BatterySnapshot(
            percentage: 80,
            isCharging: false,
            isConnectedToPower: false,
            minutesRemaining: 180
        )
        XCTAssertEqual(
            BatteryStatusController.safetyRefreshInterval(for: discharging),
            5 * 60
        )
        XCTAssertEqual(
            BatteryStatusController.safetyRefreshInterval(for: nil),
            5 * 60
        )
    }

    @MainActor
    func testRecentSuccessfulReadSkipsMenuOpenRefresh() {
        XCTAssertTrue(
            BatteryStatusController.shouldRefreshOnMenuOpen(
                lastSuccessfulRefreshUptime: nil,
                currentUptime: 100
            )
        )
        XCTAssertFalse(
            BatteryStatusController.shouldRefreshOnMenuOpen(
                lastSuccessfulRefreshUptime: 100,
                currentUptime: 104.99
            )
        )
        XCTAssertTrue(
            BatteryStatusController.shouldRefreshOnMenuOpen(
                lastSuccessfulRefreshUptime: 100,
                currentUptime: 105
            )
        )
    }

    @MainActor
    func testInformationalMenuRowsAreNotSelectable() {
        let item = NSMenuItem(title: "Battery information", action: nil, keyEquivalent: "")
        let row = InformationalMenuRowView(title: item.title)

        BatteryStatusController.configureInformationalItem(item, with: row)

        XCTAssertFalse(item.isEnabled)
        XCTAssertTrue(item.view === row)

        BatteryStatusController.updateInformationalItem(
            item,
            row: row,
            title: "Power Source: Battery"
        )
        XCTAssertEqual(item.title, "Power Source: Battery")
        XCTAssertEqual(row.title, "Power Source: Battery")
    }

    func testLoginItemPresentationReflectsSystemRegistrationState() {
        XCTAssertEqual(
            LoginItemManager.presentation(for: .notRegistered),
            LoginItemPresentation(
                title: "Open at Login",
                indicator: .off,
                action: .register
            )
        )
        XCTAssertEqual(
            LoginItemManager.presentation(for: .enabled),
            LoginItemPresentation(
                title: "Open at Login",
                indicator: .on,
                action: .unregister
            )
        )
        XCTAssertEqual(
            LoginItemManager.presentation(for: .requiresApproval),
            LoginItemPresentation(
                title: "Open at Login — Approval Required",
                indicator: .approvalRequired,
                action: .openSettings
            )
        )
        XCTAssertEqual(
            LoginItemManager.presentation(for: .notFound),
            LoginItemPresentation(
                title: "Open at Login",
                indicator: .off,
                action: .register
            )
        )
    }

    @MainActor
    func testSettingsPanesHaveStableTitlesAndSymbols() {
        XCTAssertEqual(
            BetterBatterySettingsPane.allCases,
            [.general, .batteryHealth]
        )
        XCTAssertEqual(BetterBatterySettingsPane.general.title, "General")
        XCTAssertEqual(
            BetterBatterySettingsPane.general.symbolName,
            "gearshape"
        )
        XCTAssertEqual(
            BetterBatterySettingsPane.batteryHealth.title,
            "Battery Health"
        )
        XCTAssertEqual(
            BetterBatterySettingsPane.batteryHealth.symbolName,
            "battery.100percent"
        )
        XCTAssertEqual(
            SettingsWindowController.batteryCycleSupportURL.absoluteString,
            "https://support.apple.com/en-us/102888"
        )
    }

    @MainActor
    func testPercentageFontMatchesClockMetrics() {
        let font = BatteryStatusController.percentageFont
        let menuBarFont = NSFont.menuBarFont(ofSize: 0)

        XCTAssertEqual(font.pointSize, menuBarFont.pointSize)
        XCTAssertEqual(
            font.familyName,
            menuBarFont.familyName
        )

        let narrowDigits = ("11" as NSString).size(withAttributes: [.font: font]).width
        let wideDigits = ("88" as NSString).size(withAttributes: [.font: font]).width
        XCTAssertEqual(narrowDigits, wideDigits, accuracy: 0.01)
    }

    @MainActor
    func testSettingsMenuItemImagesAreRemoved() {
        let item = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        let image = NSImage(size: NSSize(width: 16, height: 16))
        item.image = image
        item.onStateImage = image
        item.offStateImage = image
        item.mixedStateImage = image
        item.state = .on

        BatteryStatusController.removeImages(from: item)

        XCTAssertEqual(item.preferredImageVisibility, .hidden)
        XCTAssertNil(item.image)
        XCTAssertNil(item.onStateImage)
        XCTAssertNil(item.offStateImage)
        XCTAssertNil(item.mixedStateImage)
        XCTAssertEqual(item.state, .off)
    }
}
