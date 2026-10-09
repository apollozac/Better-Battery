import XCTest
@testable import BatteryBar

final class BatteryNotificationTrackerTests: XCTestCase {
    @MainActor
    func testCustomRowEnablesAndDisablesIndependently() {
        let row = CustomBatteryAlertRow(level: 35, enabled: false, direction: "draining")
        var changes = 0
        row.onChange = { changes += 1 }
        XCTAssertFalse(row.isEnabled)
        XCTAssertFalse(row.field.isEnabled)
        row.checkbox.performClick(nil)
        XCTAssertTrue(row.isEnabled)
        XCTAssertTrue(row.field.isEnabled)
        XCTAssertEqual(row.level, 35)
        row.checkbox.performClick(nil)
        XCTAssertFalse(row.isEnabled)
        XCTAssertFalse(row.field.isEnabled)
        XCTAssertEqual(changes, 2)
    }

    private func snapshot(_ level: Int, power: Bool = true) -> BatterySnapshot {
        BatterySnapshot(percentage: level, isCharging: power, isConnectedToPower: power, minutesRemaining: power ? nil : 120, minutesToFull: power ? 30 : nil)
    }

    func testCustomLevelParsing() {
        XCTAssertEqual(AppPreferences.parseThresholds("25, 35, 25, 100"), [25, 35, 100])
        XCTAssertEqual(AppPreferences.parseThresholds("  "), [])
        for invalid in ["0", "101", "25.5", "abc", "25,", "25,,35"] {
            XCTAssertNil(AppPreferences.parseThresholds(invalid))
        }
    }

    func testRepeatedCrossingsNotifyAndPowerChangeEstablishesBaseline() {
        var tracker = BatteryNotificationTracker()
        func process(_ level: Int, power: Bool = true) -> BatteryNotificationEvent? {
            tracker.process(snapshot: snapshot(level, power: power), chargingThresholds: [80], dischargingThresholds: [20])
        }
        XCTAssertNil(process(79))
        XCTAssertEqual(process(80)?.threshold, 80)
        XCTAssertNil(process(79))
        XCTAssertEqual(process(80)?.threshold, 80)
        XCTAssertNil(process(79, power: false))
        XCTAssertNil(process(79))
        XCTAssertEqual(process(80)?.threshold, 80)
    }

    func testEveryCrossingOption() {
        var tracker = BatteryNotificationTracker()
        for level in [79, 80, 79, 80] {
            let event = tracker.process(snapshot: snapshot(level), chargingThresholds: [80], dischargingThresholds: [])
            XCTAssertEqual(event?.threshold, level == 80 ? 80 : nil)
        }
    }

    func testWakeJumpCoalescesButDoesNotSuppressLaterCrossings() {
        var tracker = BatteryNotificationTracker()
        func process(_ level: Int) -> BatteryNotificationEvent? {
            tracker.process(snapshot: snapshot(level, power: false), chargingThresholds: [], dischargingThresholds: [5, 10, 20])
        }
        XCTAssertNil(process(25))
        XCTAssertEqual(process(8)?.threshold, 10)
        XCTAssertNil(process(21))
        XCTAssertEqual(process(19)?.threshold, 20)
        XCTAssertEqual(process(5)?.threshold, 5)
    }

    func testHoverIncludesLiveEstimateAndPowerSource() {
        XCTAssertEqual(snapshot(75).hoverDescription, "75% — Charging\nPower Source: Power Adapter\n30 min until full")
        XCTAssertEqual(snapshot(20, power: false).hoverDescription, "20% — On Battery\nPower Source: Battery\n2 hr remaining")
    }
}
