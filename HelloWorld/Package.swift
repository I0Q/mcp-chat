// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HelloWorld",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HelloWorld",
            targets: ["HelloWorld"]),
    ],
    targets: [
        .target(
            name: "HelloWorld",
            dependencies: [])
    ]
)

