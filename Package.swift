// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RPTrunk",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "RPTrunk",
            targets: ["RPTrunk"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.47.7"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", .branch("main"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "RPTrunk",
            dependencies: [.product(name: "Parsing", package: "swift-parsing")]
        ),
        .testTarget(
            name: "RPTrunkTests",
            dependencies: ["RPTrunk"]
        ),
    ]
)
