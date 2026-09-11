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
        .executable(name: "senku-render", targets: ["SenkuRender"]),
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

        // Renders screens to PNG off screen, so layout can be reviewed without
        // launching a simulator. Development tooling; not shipped in the apps.
        .testTarget(
            name: "SenkuUIUnitTests",
            dependencies: ["SenkuUI", .product(name: "SenkuCore", package: "SenkuCore")]
        ),

        .executableTarget(
            name: "SenkuRender",
            dependencies: ["SenkuUI", .product(name: "SenkuCore", package: "SenkuCore")]
        ),
    ]
)
