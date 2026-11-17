// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MacKitCore",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "MacKitCore", targets: ["MacKitCore"])
    ],
    targets: [
        .target(
            name: "MacKitCore",
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "MacKitCoreTests",
            dependencies: ["MacKitCore"],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
