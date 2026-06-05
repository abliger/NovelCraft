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
        .package(url: "https://github.com/bmoliveira/MarkdownKit.git", from: "1.7.2"),
    ],
    targets: [
        .executableTarget(
            name: "NovelCraft",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "MarkdownKit", package: "MarkdownKit"),
            ]
        ),
        .testTarget(
            name: "NovelCraftTests",
            dependencies: ["NovelCraft"]
        ),
    ]
)
