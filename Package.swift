// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WakTrainerDomainWorkout",
    platforms: [
        .iOS(.v14),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "WakTrainerDomainWorkout",
            targets: ["WakTrainerDomainWorkout"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/iosdevbyul/WakTrainerCoreModels",
            branch: "main"
        )
    ],
    targets: [
        .target(
            name: "WakTrainerDomainWorkout",
            dependencies: [
                .product(
                    name: "WakTrainerCoreModels",
                    package: "WakTrainerCoreModels"
                )
            ]
        ),
        .testTarget(
            name: "WakTrainerDomainWorkoutTests",
            dependencies: [
                "WakTrainerDomainWorkout"
            ]
        )
    ]
)
