// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WakTrainerDomainWorkout",
    platforms: [
        .iOS(.v14),
        .macOS(.v13)
    ],
    products: [
        .library(name: "WakTrainerDomainWorkout", targets: ["WakTrainerDomainWorkout"])
    ],
    dependencies: [
        .package(url: "https://github.com/iosdevbyul/WakTrainerCoreModels", branch: "main"),
        .package(url: "https://github.com/iosdevbyul/WakTrainerServiceHealthKit", branch: "main"),
        .package(url: "https://github.com/iosdevbyul/WakTrainerServiceLocation", branch: "main"),
        .package(url: "https://github.com/iosdevbyul/WakTrainerFeatureTimer", branch: "main")
    ],
    targets: [
        .target(
            name: "WakTrainerDomainWorkout",
            dependencies: [
                .product(name: "WakTrainerCoreModels", package: "WakTrainerCoreModels"),
                .product(name: "WakTrainerServiceHealthKit", package: "WakTrainerServiceHealthKit"),
                .product(name: "WakTrainerServiceLocation", package: "WakTrainerServiceLocation"),
                .product(name: "WakTrainerFeatureTimer", package: "WakTrainerFeatureTimer")
            ]
        )
    ]
)
