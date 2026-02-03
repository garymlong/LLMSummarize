// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LLMSummarize",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
    ],
    dependencies: [
        .package(url: "https://github.com/bmoliveira/MarkdownKit.git", from: "1.7.3") // Use the latest version
    ],
    targets: [
        .executableTarget(
            name: "LLMSummarizeDisplay",
            dependencies: ["MarkdownKit"],
            path: "LLMSummarizeDisplay/Sources",
            exclude: ["LLMSummarizeDisplay.entitlements"]
        )
    ]
)