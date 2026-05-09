// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ASUSFusionVPN",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ASUS Fusion VPN", targets: ["ASUSFusionVPN"])
    ],
    targets: [
        .executableTarget(
            name: "ASUSFusionVPN",
            path: "Sources/ASUSFusionVPN",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .testTarget(
            name: "ASUSFusionVPNTests",
            dependencies: ["ASUSFusionVPN"]
        )
    ]
)
