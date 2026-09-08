// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TableFlip",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "TableFlipCore", targets: ["TableFlipCore"]),
    ],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "TableFlipCore",
            dependencies: ["CSQLite"]
        ),
        .testTarget(
            name: "TableFlipCoreTests",
            dependencies: ["TableFlipCore"]
        ),
        .testTarget(
            name: "TableFlipE2ETests",
            dependencies: ["TableFlipCore"]
        ),
    ]
)

#if os(macOS)
package.products.append(.executable(name: "TableFlip", targets: ["TableFlipApp"]))
package.targets.append(
    .executableTarget(
        name: "TableFlipApp",
        dependencies: ["TableFlipCore"],
        path: "Apps/TableFlip"
    )
)
#endif
