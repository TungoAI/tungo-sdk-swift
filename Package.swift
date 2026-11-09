// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TungoSDK",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(name: "TungoSDK", targets: ["TungoSDK"]),
    ],
    targets: [
        .target(name: "TungoSDK"),
        .testTarget(name: "TungoSDKTests", dependencies: ["TungoSDK"]),
    ]
)
