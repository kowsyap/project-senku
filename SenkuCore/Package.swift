// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SenkuCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "SenkuCore", targets: ["SenkuCore"]),
        .executable(name: "senku", targets: ["SenkuCLI"]),
    ],
    targets: [
        .target(
            name: "SenkuCore",
            resources: [.process("Resources")]
        ),

        // A dependency-free command line front end. It exists so the core can be
        // exercised and smoke-tested with Command Line Tools alone — `swift test`
        // needs XCTest, which only ships inside Xcode.
        .executableTarget(name: "SenkuCLI", dependencies: ["SenkuCore"]),

        .testTarget(name: "SenkuCoreTests", dependencies: ["SenkuCore"]),
    ]
)
