import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import Testing
import UTxORPC
@testable import UTxORPCClient

@Suite("Long-lived connection")
struct ConnectionTests {
    /// Runs `body` with the fake services on a loopback HTTP/2 port.
    func withLoopbackServer(_ body: (Int) async throws -> Void) async throws {
        let transport = HTTP2ServerTransport.Posix(
            address: .ipv4(host: "127.0.0.1", port: 0),
            transportSecurity: .plaintext
        )
        try await withGRPCServer(transport: transport, services: [FakeSync(), FakeNode()]) { server in
            let address = try #require(try await server.listeningAddress?.ipv4)
            try await body(address.port)
        }
    }

    @Test func callsShareOneConnection() async throws {
        try await withLoopbackServer { port in
            let connection = try UTxORPCConnection(endpoint: try UTxORPCEndpoint(url: URL(string: "http://127.0.0.1:\(port)")!))
            for _ in 0..<5 {
                let tip = try await connection.client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
                #expect(tip.slot == 112_233_445)
            }
            await connection.close()
        }
    }

    @Test func callsAfterCloseFail() async throws {
        try await withLoopbackServer { port in
            let connection = try UTxORPCConnection(endpoint: try UTxORPCEndpoint(url: URL(string: "http://127.0.0.1:\(port)")!))
            _ = try await connection.client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest())
            await connection.close()
            // grpc-swift throws RuntimeError(clientIsStopped), not an RPCError.
            await #expect(throws: RuntimeError.self) {
                _ = try await connection.client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest())
            }
        }
    }
}
