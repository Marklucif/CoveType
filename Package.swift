// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CoveType",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "CoveType", targets: ["CoveType"])
    ],
    targets: [
        .executableTarget(
            name: "CoveType",
            path: "Sources/CoveType",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "App/Info.plist"
                ])
            ]
        )
    ]
)
