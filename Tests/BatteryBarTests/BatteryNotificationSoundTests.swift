import CryptoKit
import Foundation
import XCTest
@testable import BatteryBar

final class BatteryNotificationSoundTests: XCTestCase {
    func testSoundNamesAndFiles() {
        XCTAssertEqual(BatteryNotificationSound.allCases, [.low, .target, .full])
        XCTAssertEqual(BatteryNotificationSound.low.displayName, "Low Battery")
        XCTAssertEqual(BatteryNotificationSound.target.displayName, "Charge Target")
        XCTAssertEqual(BatteryNotificationSound.full.displayName, "Full Charge")
        XCTAssertEqual(BatteryNotificationSound.low.rawValue, "BetterBattery-Low.wav")
        XCTAssertEqual(BatteryNotificationSound.target.rawValue, "BetterBattery-Target.wav")
        XCTAssertEqual(BatteryNotificationSound.full.rawValue, "BetterBattery-Full.wav")
    }

    func testEveryDischargingThresholdUsesLowSound() {
        for threshold in [1, 5, 10, 20, 35, 80, 100] {
            let event = BatteryNotificationEvent(
                threshold: threshold,
                percentage: max(0, threshold - 1),
                direction: .discharging
            )
            XCTAssertEqual(BatteryNotificationSound.selection(for: event), .low)
        }
    }

    func testChargingTargetsBelowOneHundredUseTargetSound() {
        for threshold in [1, 20, 50, 80, 95, 99] {
            let event = BatteryNotificationEvent(
                threshold: threshold,
                percentage: 100,
                direction: .charging
            )
            XCTAssertEqual(BatteryNotificationSound.selection(for: event), .target)
        }
    }

    func testOneHundredPercentChargingThresholdUsesFullSound() {
        let event = BatteryNotificationEvent(
            threshold: 100,
            percentage: 100,
            direction: .charging
        )
        XCTAssertEqual(BatteryNotificationSound.selection(for: event), .full)
    }

    func testJumpToOneHundredKeepsEnabledEightyPercentTargetSound() throws {
        let event = try XCTUnwrap(BatteryNotificationPolicy.event(
            previousPercentage: 79,
            snapshot: fullyChargedSnapshot,
            chargingThresholds: [80],
            dischargingThresholds: []
        ))
        XCTAssertEqual(event.threshold, 80)
        XCTAssertEqual(event.percentage, 100)
        XCTAssertEqual(BatteryNotificationSound.selection(for: event), .target)
    }

    func testJumpAcrossEnabledFullThresholdUsesFullSound() throws {
        let event = try XCTUnwrap(BatteryNotificationPolicy.event(
            previousPercentage: 79,
            snapshot: fullyChargedSnapshot,
            chargingThresholds: [80, 100],
            dischargingThresholds: []
        ))
        XCTAssertEqual(event.threshold, 100)
        XCTAssertEqual(BatteryNotificationSound.selection(for: event), .full)
    }

    func testResourcesMatchApprovedL1FilesExactly() throws {
        let expectedHashes: [BatteryNotificationSound: String] = [
            .low: "7e27ee63d13439d0e518939104b124fd0a8ac6e50b76258c85d9bd6178efc1b9",
            .target: "e7a9eebd371b7fc54128880de6ca68a2923e76486dc5cda8fc3f610c067bde6c",
            .full: "ea62c7ace6119936eb56a8cf744f9e33d50942ce14802538869c50421b859cf4"
        ]
        for sound in BatteryNotificationSound.allCases {
            let data = try Data(contentsOf: resourceURL(for: sound))
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(hash, expectedHashes[sound], sound.rawValue)
        }
    }

    func testResourcesAreShortUnclippedMonoPCMWithSilentBoundaries() throws {
        for sound in BatteryNotificationSound.allCases {
            let bytes = [UInt8](try Data(contentsOf: resourceURL(for: sound)))
            XCTAssertGreaterThanOrEqual(bytes.count, 44, sound.rawValue)
            guard bytes.count >= 44 else { continue }
            XCTAssertEqual(String(bytes: bytes[0..<4], encoding: .ascii), "RIFF")
            XCTAssertEqual(String(bytes: bytes[8..<12], encoding: .ascii), "WAVE")
            XCTAssertEqual(Int(uint32(bytes, at: 4)) + 8, bytes.count)

            var format: [UInt8]?
            var audio: [UInt8]?
            var offset = 12
            while offset + 8 <= bytes.count {
                let size = Int(uint32(bytes, at: offset + 4))
                let start = offset + 8
                let end = start + size
                XCTAssertLessThanOrEqual(end, bytes.count, sound.rawValue)
                guard end <= bytes.count else { break }
                let chunk = String(bytes: bytes[offset..<(offset + 4)], encoding: .ascii)
                if chunk == "fmt " { format = Array(bytes[start..<end]) }
                if chunk == "data" { audio = Array(bytes[start..<end]) }
                offset = end + size % 2
            }
            let fmt = try XCTUnwrap(format, sound.rawValue)
            let pcm = try XCTUnwrap(audio, sound.rawValue)
            XCTAssertGreaterThanOrEqual(fmt.count, 16)
            guard fmt.count >= 16 else { continue }
            XCTAssertEqual(uint16(fmt, at: 0), 1, "Uncompressed PCM")
            XCTAssertEqual(uint16(fmt, at: 2), 1, "Mono")
            XCTAssertEqual(uint32(fmt, at: 4), 48_000)
            XCTAssertEqual(uint32(fmt, at: 8), 96_000, "Bytes per second")
            XCTAssertEqual(uint16(fmt, at: 12), 2, "Block alignment")
            XCTAssertEqual(uint16(fmt, at: 14), 16, "Bits per sample")
            XCTAssertEqual(pcm.count % 2, 0)
            guard pcm.count % 2 == 0 else { continue }

            let samples = stride(from: 0, to: pcm.count, by: 2).map {
                Int(Int16(bitPattern: uint16(pcm, at: $0)))
            }
            let duration = Double(samples.count) / 48_000
            XCTAssertGreaterThanOrEqual(duration, 0.45, sound.rawValue)
            XCTAssertLessThanOrEqual(duration, 1.1, sound.rawValue)
            XCTAssertTrue(samples.prefix(480).allSatisfy { $0 == 0 }, sound.rawValue)
            XCTAssertTrue(samples.suffix(480).allSatisfy { $0 == 0 }, sound.rawValue)
            let peak = try XCTUnwrap(samples.map { abs($0) }.max())
            XCTAssertGreaterThan(peak, 0, sound.rawValue)
            XCTAssertLessThan(Double(peak) / 32_768, pow(10, -8.0 / 20), sound.rawValue)
        }
    }

    private var fullyChargedSnapshot: BatterySnapshot {
        BatterySnapshot(
            percentage: 100,
            isCharging: false,
            isConnectedToPower: true,
            minutesRemaining: nil
        )
    }

    private func resourceURL(for sound: BatteryNotificationSound) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Sounds")
            .appendingPathComponent(sound.rawValue)
    }

    private func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
    }
}
