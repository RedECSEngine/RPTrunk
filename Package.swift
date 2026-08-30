// swift-tools-version:6.2

import CompilerPluginSupport
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
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.1"),
    ],
    targets: [
        .macro(
            name: "RPTrunkMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "RPTrunk",
            dependencies: ["RPTrunkMacros"]
        ),
        .testTarget(
            name: "RPTrunkTests",
            dependencies: ["RPTrunk"]
        ),
        .testTarget(
            name: "RPTrunkMacrosTests",
            dependencies: [
                "RPTrunkMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
