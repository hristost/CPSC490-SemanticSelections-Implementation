// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SemanticSelectionGUI",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/pvieito/PythonKit.git", .branch("master")),
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(
                from:
                    "0.4.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "NLP",
            dependencies: ["PythonKit"],
            exclude: ["Resources/__pycache__"],
            resources: [.copy("Resources/supar_bridge.py")]
        ),
        .target(
            name: "SemanticSelectionGUI",
            dependencies: [
                "NLP",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"),
            ]),
        .testTarget(
            name: "NLPTests",
            dependencies: ["NLP"]),
        .testTarget(
            name: "SemanticSelectionGUITests",
            dependencies: ["SemanticSelectionGUI"]),
    ]
)
