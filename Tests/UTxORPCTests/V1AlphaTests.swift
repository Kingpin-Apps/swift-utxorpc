import Foundation
import GRPCCore
import GRPCInProcessTransport
import Testing
import UTxORPC
import UTxORPCV1Alpha
@testable import UTxORPCClient

/// A v1alpha-only server, the way cardano-node-api answers.
struct FakeV1AlphaSync: Utxorpc_V1alpha_Sync_SyncService.SimpleServiceProtocol {
    func fetchBlock(
        request: Utxorpc_V1alpha_Sync_FetchBlockRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Sync_FetchBlockResponse {
        throw RPCError(code: .unimplemented, message: "fetchBlock")
    }

    func dumpHistory(
        request: Utxorpc_V1alpha_Sync_DumpHistoryRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Sync_DumpHistoryResponse {
        throw RPCError(code: .unimplemented, message: "dumpHistory")
    }

    func followTip(
        request: Utxorpc_V1alpha_Sync_FollowTipRequest,
        response: RPCWriter<Utxorpc_V1alpha_Sync_FollowTipResponse>,
        context: ServerContext
    ) async throws {
        throw RPCError(code: .unimplemented, message: "followTip")
    }

    func readTip(
        request: Utxorpc_V1alpha_Sync_ReadTipRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Sync_ReadTipResponse {
        .with {
            $0.tip = .with {
                $0.slot = 99_000_000
                $0.hash = Data(repeating: 0xCD, count: 32)
                $0.height = 10_500_000
            }
        }
    }
}

struct FakeV1AlphaQuery: Utxorpc_V1alpha_Query_QueryService.SimpleServiceProtocol {
    func readParams(
        request: Utxorpc_V1alpha_Query_ReadParamsRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_ReadParamsResponse {
        .with {
            $0.values.cardano = .with {
                $0.maxTxSize = 16_384
                $0.minFeeConstant = .with { $0.int = 155_381 }
            }
        }
    }

    func readUtxos(
        request: Utxorpc_V1alpha_Query_ReadUtxosRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_ReadUtxosResponse {
        throw RPCError(code: .unimplemented, message: "readUtxos")
    }

    /// One UTxO holding ADA and a token; no further pages.
    func searchUtxos(
        request: Utxorpc_V1alpha_Query_SearchUtxosRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_SearchUtxosResponse {
        .with {
            $0.items = [.with {
                $0.txoRef = .with {
                    $0.hash = Data(repeating: 0x11, count: 32)
                    $0.index = 3
                }
                $0.nativeBytes = Data([0x82])
                $0.cardano = .with {
                    $0.address = request.predicate.match.cardano.address.exactAddress
                    $0.coin = .with { $0.int = 2_000_000 }
                    $0.assets = [.with {
                        $0.policyID = Data(repeating: 0x22, count: 28)
                        $0.assets = [.with {
                            $0.name = Data("T".utf8)
                            $0.outputCoin = .with { $0.int = 7 }
                        }]
                    }]
                }
            }]
        }
    }

    func readData(
        request: Utxorpc_V1alpha_Query_ReadDataRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_ReadDataResponse {
        throw RPCError(code: .unimplemented, message: "readData")
    }

    func readTx(
        request: Utxorpc_V1alpha_Query_ReadTxRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_ReadTxResponse {
        throw RPCError(code: .unimplemented, message: "readTx")
    }

    func readGenesis(
        request: Utxorpc_V1alpha_Query_ReadGenesisRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_ReadGenesisResponse {
        throw RPCError(code: .unimplemented, message: "readGenesis")
    }

    func readEraSummary(
        request: Utxorpc_V1alpha_Query_ReadEraSummaryRequest, context: ServerContext
    ) async throws -> Utxorpc_V1alpha_Query_ReadEraSummaryResponse {
        throw RPCError(code: .unimplemented, message: "readEraSummary")
    }
}

/// Runs `body` with the v1beta clients against `services`, routed to `apiVersion`.
func withRoutedServer(
    services: [any RegistrableRPCService],
    apiVersion: UTxORPCAPIVersion,
    _ body: (UTxORPCClient<UTxORPCTransport<InProcessTransport.Client>>) async throws -> Void
) async throws {
    let transport = InProcessTransport()
    try await withGRPCServer(transport: transport.server, services: services) { _ in
        try await withGRPCClient(transport: UTxORPCTransport(wrapping: transport.client, apiVersion: apiVersion)) {
            try await body(UTxORPCClient(wrapping: $0))
        }
    }
}

@Suite("v1alpha servers")
struct V1AlphaTests {
    @Test func routesOnlyUTxORPCServices() {
        let transport = UTxORPCTransport(wrapping: InProcessTransport().client, apiVersion: .v1alpha)
        let readTip = Utxorpc_V1beta_Sync_SyncService.Method.ReadTip.descriptor
        #expect(transport.route(readTip).fullyQualifiedMethod == "utxorpc.v1alpha.sync.SyncService/ReadTip")
        #expect(transport.route(readTip).type == readTip.type)

        let getEra = MethodDescriptor(fullyQualifiedService: "cardano.rpc.Node", method: "GetEra")
        #expect(transport.route(getEra) == getEra)

        let beta = UTxORPCTransport(wrapping: InProcessTransport().client, apiVersion: .v1beta)
        #expect(beta.route(readTip) == readTip)
    }

    @Test func endpointCarriesTheVersion() throws {
        let endpoint = try UTxORPCEndpoint(url: URL(string: "http://127.0.0.1:9090")!, apiVersion: .v1alpha)
        #expect(endpoint.apiVersion == .v1alpha)
        #expect(UTxORPCEndpoint.unixSocket("/x").apiVersion == .v1beta)
        #expect(try endpoint.makeTransport().apiVersion == .v1alpha)
    }

    @Test func v1betaClientsReadAV1alphaServer() async throws {
        try await withRoutedServer(services: [FakeV1AlphaSync(), FakeV1AlphaQuery()], apiVersion: .v1alpha) { client in
            let tip = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
            #expect(tip.slot == 99_000_000)
            #expect(tip.height == 10_500_000)
            #expect(tip.hash == Data(repeating: 0xCD, count: 32))

            let params = try await client.query.readParams(Utxorpc_V1beta_Query_ReadParamsRequest()).values.cardano
            #expect(params.maxTxSize == 16_384)
            #expect(params.minFeeConstant.int == 155_381)

            let address = Data(repeating: 0x61, count: 29)
            let page = try await client.query.searchUtxos(.with {
                $0.predicate.match.cardano.address.exactAddress = address
            })
            let item = try #require(page.items.first)
            #expect(item.txoRef.index == 3)
            #expect(item.nativeBytes == Data([0x82]))
            #expect(item.cardano.address == address)
            #expect(item.cardano.coin.int == 2_000_000)
            #expect(item.cardano.assets.first?.assets.first?.quantity.int == 7)
            #expect(!page.hasNextToken)
        }
    }

    /// A v1beta server has no v1alpha services, so a v1alpha call reaches nothing.
    @Test func v1alphaCallsMissAV1betaServer() async throws {
        try await withRoutedServer(services: [FakeSync()], apiVersion: .v1alpha) { client in
            let error = await #expect(throws: RPCError.self) {
                _ = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest())
            }
            #expect(error?.code == .unimplemented)
        }
    }
}
