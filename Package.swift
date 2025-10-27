// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mcp-chat",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/Cocoanetics/SwiftMCP.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "mcp-chat",
            dependencies: [
                .product(name: "SwiftMCP", package: "SwiftMCP")
            ]
        )
    ]
)

