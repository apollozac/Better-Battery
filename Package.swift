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
    dependencies: [
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.9.2"
        )
    ],
    targets: [
        .executableTarget(
            name: "BatteryBar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        ),
        .testTarget(
            name: "BatteryBarTests",
            dependencies: ["BatteryBar"]
        )
    ]
)
