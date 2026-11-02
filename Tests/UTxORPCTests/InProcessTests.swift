import Foundation
import GRPCCore
import GRPCInProcessTransport
import Synchronization
import SwiftProtobuf
import Testing
import UTxORPC
import UTxORPCCardanoNode
@testable import UTxORPCClient

/// Serves fixed answers, the way a node or Dolos would.
struct FakeSync: Utxorpc_V1beta_Sync_SyncService.SimpleServiceProtocol {
    func fetchBlock(
        request: Utxorpc_V1beta_Sync_FetchBlockRequest, context: ServerContext
    ) async throws -> Utxorpc_V1beta_Sync_FetchBlockResponse {
        throw RPCError(code: .unimplemented, message: "fetchBlock")
    }

    func dumpHistory(
        request: Utxorpc_V1beta_Sync_DumpHistoryRequest, context: ServerContext
    ) async throws -> Utxorpc_V1beta_Sync_DumpHistoryResponse {
        throw RPCError(code: .unimplemented, message: "dumpHistory")
    }

    func followTip(
        request: Utxorpc_V1beta_Sync_FollowTipRequest,
        response: RPCWriter<Utxorpc_V1beta_Sync_FollowTipResponse>,
        context: ServerContext
    ) async throws {
        throw RPCError(code: .unimplemented, message: "followTip")
    }

    func readTip(
        request: Utxorpc_V1beta_Sync_ReadTipRequest, context: ServerContext
    ) async throws -> Utxorpc_V1beta_Sync_ReadTipResponse {
        .with {
            $0.tip = .with {
                $0.slot = 112_233_445
                $0.hash = Data(repeating: 0xAB, count: 32)
                $0.height = 11_000_000
            }
        }
    }
}

struct FakeNode: Cardano_Rpc_Node.SimpleServiceProtocol {
    func getEra(
        request: Google_Protobuf_Empty, context: ServerContext
    ) async throws -> Cardano_Rpc_CurrentEra {
        .with { $0.era = .conway }
    }

    func getProtocolParamsJson(
        request: Google_Protobuf_Empty, context: ServerContext
    ) async throws -> Cardano_Rpc_ProtocolParamsJson {
        .with { $0.json = Data(#"{"maxTxSize":16384}"#.utf8) }
    }
}

/// Records the request metadata the server saw.
final class MetadataRecorder: ServerInterceptor {
    let seen = Mutex<[String: String]>([:])

    func intercept<Input: Sendable, Output: Sendable>(
        request: StreamingServerRequest<Input>,
        context: ServerContext,
        next: (StreamingServerRequest<Input>, ServerContext) async throws -> StreamingServerResponse<Output>
    ) async throws -> StreamingServerResponse<Output> {
        let values = request.metadata.reduce(into: [String: String]()) { out, entry in
            if case .string(let value) = entry.value { out[entry.key] = value }
        }
        seen.withLock { $0.merge(values) { _, new in new } }
        return try await next(request, context)
    }
}

/// Runs `body` against the fake services over an in-process transport.
func withFakeServer(
    headers: [String: String] = [:],
    recorder: MetadataRecorder = MetadataRecorder(),
    _ body: (UTxORPCClient<InProcessTransport.Client>) async throws -> Void
) async throws {
    let transport = InProcessTransport()
    try await withGRPCServer(
        transport: transport.server,
        services: [FakeSync(), FakeNode()],
        interceptors: [recorder]
    ) { _ in
        let endpoint = UTxORPCEndpoint(target: .unixSocket(path: "unused"), useTLS: false, headers: headers)
        try await withGRPCClient(transport: transport.client, interceptors: endpoint.interceptors) { client in
            try await body(UTxORPCClient(wrapping: client))
        }
    }
}

@Suite("In-process server")
struct InProcessTests {
    @Test func readTip() async throws {
        try await withFakeServer { client in
            let tip = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
            #expect(tip.slot == 112_233_445)
            #expect(tip.height == 11_000_000)
            #expect(tip.hash == Data(repeating: 0xAB, count: 32))
        }
    }

    @Test func nodeService() async throws {
        try await withFakeServer { client in
            #expect(try await client.node.getEra(Google_Protobuf_Empty()).era == .conway)
            let json = try await client.node.getProtocolParamsJson(Google_Protobuf_Empty()).json
            #expect(String(decoding: json, as: UTF8.self) == #"{"maxTxSize":16384}"#)
        }
    }

    @Test func unimplementedCallsSurfaceAsRPCError() async throws {
        try await withFakeServer { client in
            let error = await #expect(throws: RPCError.self) {
                _ = try await client.sync.dumpHistory(Utxorpc_V1beta_Sync_DumpHistoryRequest())
            }
            #expect(error?.code == .unimplemented)
        }
    }

    @Test func headersReachTheServer() async throws {
        let recorder = MetadataRecorder()
        try await withFakeServer(headers: ["DMTR-API-KEY": "secret"], recorder: recorder) { client in
            _ = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest())
        }
        #expect(recorder.seen.withLock { $0["dmtr-api-key"] } == "secret")
    }
}
