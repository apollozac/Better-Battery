import Foundation
#if APP_STORE
import IOKit
#endif

struct BatteryHealthSnapshot: Equatable {
    let condition: String?
    let maximumCapacity: Int?
    let cycleCount: Int?
}

struct BatteryHealthReader {
    func currentSnapshot() -> BatteryHealthSnapshot? {
#if APP_STORE
        guard let properties = Self.smartBatteryProperties() else {
            return nil
        }

        let batteryData = properties["BatteryData"] as? [String: Any]
        let condition = properties["BatteryHealth"] as? String
        let cycleCount = Self.integer(
            properties["CycleCount"] ?? batteryData?["CycleCount"]
        )

        guard condition != nil || cycleCount != nil else {
            return nil
        }

        return BatteryHealthSnapshot(
            condition: condition,
            maximumCapacity: nil,
            cycleCount: cycleCount
        )
#else
        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPPowerDataType", "-json"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        return Self.parse(data: data)
#endif
    }

#if APP_STORE
    private static func smartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else {
            return nil
        }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &unmanagedProperties,
            kCFAllocatorDefault,
            0
        )
        guard
            result == KERN_SUCCESS,
            let properties = unmanagedProperties?.takeRetainedValue()
                as? [String: Any]
        else {
            return nil
        }
        return properties
    }

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        return value as? Int
    }
#endif

    static func parse(data: Data) -> BatteryHealthSnapshot? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let items = root["SPPowerDataType"] as? [[String: Any]],
            let health = items.compactMap({
                $0["sppower_battery_health_info"] as? [String: Any]
            }).first
        else {
            return nil
        }

        let condition = health["sppower_battery_health"] as? String
        let cycleCount = health["sppower_battery_cycle_count"] as? Int
        let capacityString = health["sppower_battery_health_maximum_capacity"] as? String
        let maximumCapacity = capacityString.flatMap {
            Int($0.trimmingCharacters(in: CharacterSet(charactersIn: "%")))
        }

        guard condition != nil || cycleCount != nil || maximumCapacity != nil else {
            return nil
        }

        return BatteryHealthSnapshot(
            condition: condition,
            maximumCapacity: maximumCapacity,
            cycleCount: cycleCount
        )
    }
}
