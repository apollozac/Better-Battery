import Foundation
import IOKit
import IOKit.ps

struct BatteryReader {
    func currentSnapshot() -> BatterySnapshot? {
        guard
            let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let powerSources = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for powerSource in powerSources {
            guard
                let rawDescription = IOPSGetPowerSourceDescription(powerSourcesInfo, powerSource)?
                    .takeUnretainedValue() as? [String: Any],
                rawDescription[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else {
                continue
            }

            let currentCapacity = rawDescription[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximumCapacity = rawDescription[kIOPSMaxCapacityKey] as? Int ?? 100
            guard let percentage = BatterySnapshot.percentage(
                current: currentCapacity,
                maximum: maximumCapacity
            ) else {
                continue
            }

            let isCharging = rawDescription[kIOPSIsChargingKey] as? Bool ?? false
            let powerSourceState = rawDescription[kIOPSPowerSourceStateKey] as? String
            let isConnectedToPower = powerSourceState == kIOPSACPowerValue
            let isFinishingCharge =
                rawDescription[kIOPSIsFinishingChargeKey] as? Bool ?? false
            let reportedIsCharged = rawDescription[kIOPSIsChargedKey] as? Bool
            let isFullyCharged = reportedIsCharged
                ?? (
                    isConnectedToPower
                        && !isCharging
                        && !isFinishingCharge
                        && percentage >= 100
                )
            let estimates = Self.timeEstimates(
                isConnectedToPower: isConnectedToPower,
                isCharging: isCharging,
                isFullyCharged: isFullyCharged,
                isFinishingCharge: isFinishingCharge,
                reportedMinutesRemaining: rawDescription[kIOPSTimeToEmptyKey] as? Int,
                reportedMinutesToFull: rawDescription[kIOPSTimeToFullChargeKey] as? Int,
                globalMinutesRemaining: Self.globalMinutesRemaining,
                registryMinutesToFull: Self.registryMinutesToFull
            )

            return BatterySnapshot(
                percentage: percentage,
                isCharging: isCharging,
                isConnectedToPower: isConnectedToPower,
                isFullyCharged: isFullyCharged,
                isFinishingCharge: isFinishingCharge,
                minutesRemaining: estimates.remaining,
                minutesToFull: estimates.toFull
            )
        }

        return nil
    }

    static func minutesRemaining(from seconds: TimeInterval) -> Int? {
        guard seconds.isFinite, seconds > 0 else {
            return nil
        }

        return max(1, Int((seconds / 60).rounded()))
    }

    static func timeEstimates(
        isConnectedToPower: Bool,
        isCharging: Bool,
        isFullyCharged: Bool,
        isFinishingCharge: Bool,
        reportedMinutesRemaining: Int?,
        reportedMinutesToFull: Int?,
        globalMinutesRemaining: () -> Int?,
        registryMinutesToFull: () -> Int?
    ) -> (remaining: Int?, toFull: Int?) {
        let remaining = isConnectedToPower
            ? nil
            : validEstimate(reportedMinutesRemaining) ?? globalMinutesRemaining()

        let shouldEstimateTimeToFull =
            isConnectedToPower
                && isCharging
                && !isFullyCharged
                && !isFinishingCharge
        let toFull = shouldEstimateTimeToFull
            ? validEstimate(reportedMinutesToFull) ?? registryMinutesToFull()
            : nil

        return (remaining, toFull)
    }

    private static func validEstimate(_ minutes: Int?) -> Int? {
        guard let minutes, minutes > 0, minutes < 65_535 else {
            return nil
        }
        return minutes
    }

    private static func globalMinutesRemaining() -> Int? {
        minutesRemaining(from: IOPSGetTimeRemainingEstimate())
    }

    private static func registryMinutesToFull() -> Int? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != 0 else {
            return nil
        }
        defer {
            IOObjectRelease(service)
        }

        guard
            let value = IORegistryEntryCreateCFProperty(
                service,
                "AvgTimeToFull" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? NSNumber
        else {
            return nil
        }

        return validEstimate(value.intValue)
    }
}
