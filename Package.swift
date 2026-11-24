// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WantMyMTV",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "WantMyMTV",
            targets: ["WantMyMTV"]
        ),
    ],
    dependencies: [
        // Generates typed Swift (L10n.helloWorld) from the strings in
        // Sources/<App>/Resources at build time. Config: Sources/<App>/swiftgen.yml.
        .package(url: "https://github.com/SwiftGen/SwiftGenPlugin", from: "6.6.2"),
    ],
    targets: [
        .target(
            name: "WantMyMTV",
            exclude: ["swiftgen.yml"],
            resources: [
                .process("Resources"),
                // The icon on the loading screen.
                .copy("LaunchIcon.png"),
            ],
            plugins: [
                .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin"),
            ]
        ),
    ]
)
