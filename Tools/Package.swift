// swift-tools-version: 6.2
// Builds the pinned code generators used by `just generate`, so generation
// does not depend on a Homebrew protoc.

import PackageDescription

let package = Package(
    name: "UTxORPCTools",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.39.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", exact: "2.5.0"),
    ],
    targets: []
)
