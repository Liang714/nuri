// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuriDesignSystem",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DesignSystem", targets: ["DesignSystem"])],
    dependencies: [.package(path: "../NuriEngines")],
    targets: [
        .target(
            name: "DesignSystem",
            dependencies: [.product(name: "NuriDomain", package: "NuriEngines")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem", .product(name: "NuriDomain", package: "NuriEngines")]
        ),
    ]
)
