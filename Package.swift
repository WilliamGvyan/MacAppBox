// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacAppBox",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacAppBox", targets: ["MacAppBox"])
    ],
    targets: [
        .executableTarget(
            name: "MacAppBox",
            path: "Sources/MacAppBox"
        )
    ],
    swiftLanguageModes: [.v5]
)
