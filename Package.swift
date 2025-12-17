// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WikiMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "wikimcp", targets: ["WikiMCP"]),
        .executable(name: "wikicli", targets: ["WikiCLI"]),
        .library(name: "WikiCore", targets: ["WikiCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
    ],
    targets: [
        // 共享核心库
        .target(
            name: "WikiCore",
            dependencies: [
                "SwiftSoup",
                "Alamofire",
            ]
        ),
        // MCP 版本 (原有)
        .executableTarget(
            name: "WikiMCP",
            dependencies: [
                "WikiCore",
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
        // CLI 版本 (用于 Agent Skill)
        .executableTarget(
            name: "WikiCLI",
            dependencies: [
                "WikiCore",
            ]
        ),
    ]
)
