// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NuriPersistence",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "Persistence", targets: ["Persistence"])],
    dependencies: [.package(path: "../NuriEngines")],
    targets: [
        .target(name: "Persistence", dependencies: [
            .product(name: "NuriDomain", package: "NuriEngines"),
            .product(name: "NutritionEngine", package: "NuriEngines"),
            .product(name: "ActivityEngine", package: "NuriEngines"),
        ]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
    ]
)
