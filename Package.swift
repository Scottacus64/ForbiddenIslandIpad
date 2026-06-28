// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ForbiddenIslandRules",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ForbiddenIslandRules",
            targets: ["ForbiddenIslandRules"]
        )
    ],
    targets: [
        .target(
            name: "ForbiddenIslandRules",
            path: "ForbiddenIslandIpad/Rules"
        ),
        .testTarget(
            name: "ForbiddenIslandRulesTests",
            dependencies: ["ForbiddenIslandRules"],
            path: "ForbiddenIslandIpadTests/RulesTests"
        )
    ]
)
