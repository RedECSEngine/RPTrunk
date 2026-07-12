// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "RPTrunk",
    // Matches swift-parsing's minimum requirements.
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "RPTrunk",
            targets: ["RPTrunk"]
        ),
    ],
    targets: [
        .target(
            name: "RPTrunk"
        ),
        .testTarget(
            name: "RPTrunkTests",
            dependencies: ["RPTrunk"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
