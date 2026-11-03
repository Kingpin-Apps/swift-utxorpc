import Foundation
import GRPCCore
import SwiftProtobuf
import Testing
import UTxORPC
import UTxORPCCardanoNode
import UTxORPCClient

/// Talks to real servers. Off unless the environment names one:
/// - `UTXORPC_NODE_SOCKET`: a cardano-node `rpc.sock` (node started with `EnableRpc`)
/// - `UTXORPC_URL` (+ optional `UTXORPC_API_KEY`, sent as `dmtr-api-key`): Dolos or Demeter
@Suite("Live servers")
struct LiveTests {
    static let nodeSocket = ProcessInfo.processInfo.environment["UTXORPC_NODE_SOCKET"]
    static let serverURL = ProcessInfo.processInfo.environment["UTXORPC_URL"]

    @Test(.enabled(if: nodeSocket != nil, "set UTXORPC_NODE_SOCKET"))
    func cardanoNode() async throws {
        try await withUTxORPCClient(endpoint: .unixSocket(Self.nodeSocket!)) { client in
            let tip = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
            #expect(tip.slot > 0)
            #expect(tip.hash.count == 32)

            #expect(try await client.node.getEra(Google_Protobuf_Empty()).era == .conway)

            let params = try await client.query.readParams(Utxorpc_V1beta_Query_ReadParamsRequest())
            #expect(params.values.cardano.maxTxSize > 0)

            let json = try await client.node.getProtocolParamsJson(Google_Protobuf_Empty()).json
            #expect(try JSONSerialization.jsonObject(with: json) is [String: Any])
        }
    }

    @Test(.enabled(if: serverURL != nil, "set UTXORPC_URL"))
    func hostedServer() async throws {
        var headers: [String: String] = [:]
        if let key = ProcessInfo.processInfo.environment["UTXORPC_API_KEY"] {
            headers["dmtr-api-key"] = key
        }
        let endpoint = try UTxORPCEndpoint(url: URL(string: Self.serverURL!)!, headers: headers)
        try await withUTxORPCClient(endpoint: endpoint) { client in
            let tip = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
            #expect(tip.slot > 0)
            let params = try await client.query.readParams(Utxorpc_V1beta_Query_ReadParamsRequest())
            #expect(params.values.cardano.maxTxSize > 0)
        }
    }

    /// Ten calls over one TLS connection against ten connections, one per call.
    @Test(.enabled(if: serverURL != nil, "set UTXORPC_URL"))
    func connectionReuseSavesTheHandshake() async throws {
        let headers = ProcessInfo.processInfo.environment["UTXORPC_API_KEY"].map { ["dmtr-api-key": $0] } ?? [:]
        let endpoint = try UTxORPCEndpoint(url: URL(string: Self.serverURL!)!, headers: headers)
        let request = Utxorpc_V1beta_Sync_ReadTipRequest()
        let clock = ContinuousClock()

        let perCall = try await clock.measure {
            for _ in 0..<10 {
                try await withUTxORPCClient(endpoint: endpoint) { _ = try await $0.sync.readTip(request) }
            }
        }
        let connection = try UTxORPCConnection(endpoint: endpoint)
        let reused = try await clock.measure {
            for _ in 0..<10 { _ = try await connection.client.sync.readTip(request) }
        }
        await connection.close()
        print("UTxO RPC 10 × ReadTip: \(perCall) one connection each, \(reused) over one connection")
        #expect(reused < perCall)
    }
}
