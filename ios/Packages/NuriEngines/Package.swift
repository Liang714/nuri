// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuriEngines",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NuriDomain", targets: ["NuriDomain"]),
        .library(name: "NutritionEngine", targets: ["NutritionEngine"]),
        .library(name: "ActivityEngine", targets: ["ActivityEngine"]),
    ],
    targets: [
        .target(name: "NuriDomain"),
        .target(name: "NutritionEngine", dependencies: ["NuriDomain"]),
        .target(
            name: "ActivityEngine",
            dependencies: ["NuriDomain", "NutritionEngine"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "NuriDomainTests", dependencies: ["NuriDomain"]),
        .testTarget(name: "NutritionEngineTests", dependencies: ["NutritionEngine", "NuriDomain"]),
        .testTarget(name: "ActivityEngineTests", dependencies: ["ActivityEngine", "NutritionEngine", "NuriDomain"]),
        .testTarget(name: "PublicAPITests", dependencies: ["NuriDomain", "NutritionEngine", "ActivityEngine"]),
    ]
)
