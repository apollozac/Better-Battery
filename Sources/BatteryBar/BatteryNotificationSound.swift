import Foundation
@preconcurrency import UserNotifications

enum BatteryNotificationSound: String, CaseIterable, Sendable {
    case low = "BetterBattery-Low.wav"
    case target = "BetterBattery-Target.wav"
    case full = "BetterBattery-Full.wav"

    var displayName: String {
        switch self {
        case .low:
            return "Low Battery"
        case .target:
            return "Charge Target"
        case .full:
            return "Full Charge"
        }
    }

    // Version names when recordings change, so Notification Center does not
    // reuse a cached lookup for a previous recording.
    var notificationFilename: String {
        switch self {
        case .low: return "better-battery-l1-low.wav"
        case .target: return "better-battery-l1-target.wav"
        case .full: return "better-battery-l1-full.wav"
        }
    }

    var sound: UNNotificationSound {
        UNNotificationSound(named: UNNotificationSoundName(rawValue: notificationFilename))
    }

    static func installBundledSounds(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) throws -> Int {
        guard let resources = bundle.resourceURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        let library = try fileManager.url(
            for: .libraryDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        return try install(
            from: resources,
            to: library.appendingPathComponent("Sounds", isDirectory: true),
            fileManager: fileManager
        )
    }

    /// Prepare once at launch, without timers or rewriting unchanged files.
    /// The user Library resolves inside the app container in sandboxed builds.
    @discardableResult
    static func install(
        from resources: URL,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws -> Int {
        // Validate every source before modifying the destination.
        let recordings = try allCases.map { sound in
            (sound, try Data(contentsOf: resources.appendingPathComponent(sound.rawValue)))
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        var writes = 0
        for (sound, data) in recordings {
            let url = destination.appendingPathComponent(sound.notificationFilename)
            if (try? Data(contentsOf: url)) == data { continue }
            try data.write(to: url, options: .atomic)
            writes += 1
        }
        return writes
    }

    static func selection(for event: BatteryNotificationEvent) -> Self {
        if event.direction == .discharging {
            return .low
        }
        // Use the crossed threshold, not the current reading: a jump to 100%
        // crossing only an enabled 80% alert is still a charge-target alert.
        return event.threshold == 100 ? .full : .target
    }
}
