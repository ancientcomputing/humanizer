// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HumanizerApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "HumanizerApp", targets: ["HumanizerApp"])
    ],
    targets: [
        .executableTarget(
            name: "HumanizerApp"
        )
    ]
)
