tools := "Tools/.build/release"
gen := "Sources"

build:
    swift build

test:
    swift test

release:
    swift build -c release

# Build protoc and the Swift plugins at the versions pinned in Tools/Package.swift
tools:
    swift build -c release --package-path Tools --product protoc
    swift build -c release --package-path Tools --product protoc-gen-swift
    swift build -c release --package-path Tools --product protoc-gen-grpc-swift-2

# Regenerate the Swift code from Protos/
generate: tools
    rm -rf {{gen}}/UTxORPC/Generated {{gen}}/UTxORPCV1Alpha/Generated {{gen}}/UTxORPCCardanoNode/Generated
    mkdir -p {{gen}}/UTxORPC/Generated {{gen}}/UTxORPCV1Alpha/Generated {{gen}}/UTxORPCCardanoNode/Generated
    {{tools}}/protoc -I Protos \
        --plugin={{tools}}/protoc-gen-swift \
        --plugin={{tools}}/protoc-gen-grpc-swift-2 \
        --swift_out={{gen}}/UTxORPC/Generated --swift_opt=Visibility=Public,FileNaming=PathToUnderscores \
        --grpc-swift-2_out={{gen}}/UTxORPC/Generated --grpc-swift-2_opt=Visibility=Public,FileNaming=PathToUnderscores \
        $(find Protos/utxorpc/v1beta -name '*.proto' | sort)
    {{tools}}/protoc -I Protos \
        --plugin={{tools}}/protoc-gen-swift \
        --plugin={{tools}}/protoc-gen-grpc-swift-2 \
        --swift_out={{gen}}/UTxORPCV1Alpha/Generated --swift_opt=Visibility=Public,FileNaming=PathToUnderscores \
        --grpc-swift-2_out={{gen}}/UTxORPCV1Alpha/Generated --grpc-swift-2_opt=Visibility=Public,FileNaming=PathToUnderscores \
        $(find Protos/utxorpc/v1alpha -name '*.proto' | sort)
    {{tools}}/protoc -I Protos \
        --plugin={{tools}}/protoc-gen-swift \
        --plugin={{tools}}/protoc-gen-grpc-swift-2 \
        --swift_out={{gen}}/UTxORPCCardanoNode/Generated --swift_opt=Visibility=Public,FileNaming=PathToUnderscores \
        --grpc-swift-2_out={{gen}}/UTxORPCCardanoNode/Generated --grpc-swift-2_opt=Visibility=Public,FileNaming=PathToUnderscores \
        Protos/cardano/rpc/node.proto

# Update changelog
changelog:
    cz ch

# Bump version according to changelog
bump: changelog
    cz bump
