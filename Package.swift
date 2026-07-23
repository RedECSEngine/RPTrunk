// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "RPTrunk",
    // Minimum that ships `CodingKeyRepresentable`, which `RPCode` needs so a
    // dictionary keyed by a code still encodes as a JSON object.
    platforms: [
        .iOS("15.4"),
        .macOS("12.3"),
        .tvOS("15.4"),
        .watchOS("8.5"),
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
