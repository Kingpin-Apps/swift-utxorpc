// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftUTxORPC",
    // grpc-swift 2 sets these floors.
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "UTxORPC", targets: ["UTxORPC"]),
        .library(name: "UTxORPCV1Alpha", targets: ["UTxORPCV1Alpha"]),
        .library(name: "UTxORPCCardanoNode", targets: ["UTxORPCCardanoNode"]),
        .library(name: "UTxORPCClient", targets: ["UTxORPCClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.4.4"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.5.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.12.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.39.0"),
    ],
    targets: [
        // Messages and service clients generated from Protos/utxorpc (`just generate`).
        .target(
            name: "UTxORPC",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        // The older v1alpha API, generated from Protos/utxorpc/v1alpha, for servers
        // that never moved to v1beta (cardano-node-api).
        .target(
            name: "UTxORPCV1Alpha",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        // cardano-node's own cardano.rpc.Node service, generated from Protos/cardano.
        .target(
            name: "UTxORPCCardanoNode",
            dependencies: [
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        // Connection setup (TCP, TLS, Unix socket, API-key headers) over the generated clients.
        .target(
            name: "UTxORPCClient",
            dependencies: [
                "UTxORPC",
                "UTxORPCCardanoNode",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
            ]
        ),
        .testTarget(
            name: "UTxORPCTests",
            dependencies: [
                "UTxORPC",
                "UTxORPCV1Alpha",
                "UTxORPCCardanoNode",
                "UTxORPCClient",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCInProcessTransport", package: "grpc-swift-2"),
            ]
        ),
    ]
)
