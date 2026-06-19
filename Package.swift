// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "droidspaces-vz",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "dsvz", targets: ["dsvz"])
    ],
    targets: [
        .executableTarget(
            name: "dsvz"
        )
    ]
)
