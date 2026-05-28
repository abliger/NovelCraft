// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NovelCraft",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],

    products: [
        .executable(
            name: "NovelCraft",
            targets: ["NovelCraft"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .executableTarget(
            name: "NovelCraft",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
            ]
        ),
        .testTarget(
            name: "NovelCraftTests",
            dependencies: ["NovelCraft"]
        ),
    ]
)
