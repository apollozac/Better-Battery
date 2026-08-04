// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "BetterBattery",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "BetterBattery", targets: ["BatteryBar"])
    ],
    targets: [
        .executableTarget(
            name: "BatteryBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "BatteryBarTests",
            dependencies: ["BatteryBar"]
        )
    ]
)
