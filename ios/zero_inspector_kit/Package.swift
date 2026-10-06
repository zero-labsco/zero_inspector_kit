// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "zero_inspector_kit",
    platforms: [
        // iOS only; matches the deployment target in zero_inspector_kit.podspec.
        .iOS("13.0")
    ],
    products: [
        // The plugin name contains "_", so the library name uses "-" separators.
        .library(name: "zero-inspector-kit", targets: ["zero_inspector_kit"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "zero_inspector_kit",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
