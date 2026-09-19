// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SenkuUI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "SenkuUI", targets: ["SenkuUI"]),
    ],
    dependencies: [
        .package(path: "../SenkuCore"),
    ],
    targets: [
        .target(
            name: "SenkuUI",
            dependencies: [.product(name: "SenkuCore", package: "SenkuCore")],
            resources: [.process("Resources")]
        ),

        // Stores, importer, plate maths, tab layout, and the sample file —
        // everything that can be checked on the host, without a simulator.
        .testTarget(
            name: "SenkuUIUnitTests",
            dependencies: ["SenkuUI", .product(name: "SenkuCore", package: "SenkuCore")]
        ),
    ]
)
