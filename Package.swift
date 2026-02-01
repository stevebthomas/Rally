// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceLift",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "VoiceLift",
            targets: ["VoiceLift"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VoiceLift",
            dependencies: [],
            path: ".",
            sources: [
                "VoiceLiftApp.swift",
                "Models",
                "Views",
                "Services",
                "Utilities"
            ],
            resources: [
                .copy("Resources/ExerciseDatabase.json")
            ]
        )
    ]
)
