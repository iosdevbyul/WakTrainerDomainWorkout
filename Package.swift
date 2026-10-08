// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WakTrainerDomainWorkout",
    platforms: [
        .iOS(.v17),
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
            revision: "a19ca9d53b7b395b3c41efbbcc9883c53a672832"
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
