// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ReplyKit",
    platforms: [
        // Keep the deployment target at iOS 18. Foundation Models support is
        // availability-gated inside FoundationModelsClient.swift, so this
        // package must NOT be raised to iOS 26.
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "ReplyKit",
            targets: ["ReplyKit"]
        )
    ],
    targets: [
        .target(
            name: "ReplyKit",
            path: "Sources/ReplyKit"
        )
    ]
)
