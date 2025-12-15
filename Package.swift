// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WikiMCP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "wikimcp", targets: ["WikiMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.10.0"),
    ],
    targets: [
        .executableTarget(
            name: "WikiMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                "SwiftSoup",
                "Alamofire",
            ]
        ),
    ]
)

