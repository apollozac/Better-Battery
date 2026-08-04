import Foundation

struct BatteryHealthSnapshot: Equatable {
    let condition: String?
    let maximumCapacity: Int?
    let cycleCount: Int?
}

struct BatteryHealthReader {
    func currentSnapshot() -> BatteryHealthSnapshot? {
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
    }

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
