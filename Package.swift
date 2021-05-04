// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "SemanticSelectionGUI",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", .branch("master")),
        .package(url: "https://github.com/pvieito/PythonCodable.git", .branch("master")),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(
                from:
                    "0.4.0")),
    ],
    targets: [
        .target(
            name: "Backend",
            dependencies: ["PythonKit", "PythonCodable"],
            exclude: ["__pycache__"],
            resources: [.copy("supar_bridge.py")]
        ),
        .target(
            name: "Frontend",
            dependencies: [
                "Backend",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"),
            ]),
    ]
)
