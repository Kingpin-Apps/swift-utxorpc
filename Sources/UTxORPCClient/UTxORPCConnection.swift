import GRPCCore
import GRPCNIOTransportHTTP2

/// A client that stays connected for as long as it lives, so calls reuse one
/// HTTP/2 connection instead of opening (and for TLS, handshaking) one each.
///
/// The connection opens lazily on the first call and reconnects on its own
/// after the server goes away. Call ``close()`` to shut it down and wait for
/// calls in flight; dropping the last reference shuts it down without waiting.
///
/// ```swift
/// let connection = try UTxORPCConnection(endpoint: .unixSocket("/opt/cardano/socket/rpc.sock"))
/// let tip = try await connection.client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest())
/// await connection.close()
/// ```
public final class UTxORPCConnection: Sendable {
    /// The service clients, all over this one connection.
    public let client: UTxORPCClient<UTxORPCTransport<HTTP2ClientTransport.Posix>>

    private let grpc: GRPCClient<UTxORPCTransport<HTTP2ClientTransport.Posix>>
    private let connections: Task<Void, Never>

    public init(endpoint: UTxORPCEndpoint) throws {
        let grpc = GRPCClient(transport: try endpoint.makeTransport(), interceptors: endpoint.interceptors)
        self.grpc = grpc
        client = UTxORPCClient(wrapping: grpc)
        // Ends once the client shuts down. A transport failure surfaces on each
        // call as an RPCError, so the task has nothing more to report.
        connections = Task { try? await grpc.runConnections() }
    }

    /// Stops new calls, lets calls in flight finish, then closes the connection.
    public func close() async {
        grpc.beginGracefulShutdown()
        await connections.value
    }

    deinit {
        grpc.beginGracefulShutdown()
    }
}
