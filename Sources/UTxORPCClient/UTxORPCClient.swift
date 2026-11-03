import GRPCCore
import GRPCNIOTransportHTTP2
import UTxORPC
import UTxORPCCardanoNode

/// The UTxO RPC service clients over one connection.
///
/// Not every server implements every service: cardano-node has no Watch service
/// and no `ReadTx`, `ReadData` or `DumpHistory`, node 11.1.x also lacks
/// `ReadEraSummary` and the mempool calls, and only the node serves ``node``.
/// Calls a server lacks fail with `RPCError` code `.unimplemented`.
///
/// The clients are v1beta. Against a v1alpha server (cardano-node-api), an
/// endpoint with `apiVersion: .v1alpha` routes them to the v1alpha services;
/// see ``UTxORPCTransport``.
public struct UTxORPCClient<Transport: ClientTransport>: Sendable {
    public let query: Utxorpc_V1beta_Query_QueryService.Client<Transport>
    public let submit: Utxorpc_V1beta_Submit_SubmitService.Client<Transport>
    public let sync: Utxorpc_V1beta_Sync_SyncService.Client<Transport>
    public let watch: Utxorpc_V1beta_Watch_WatchService.Client<Transport>
    /// cardano-node's own `cardano.rpc.Node` service.
    public let node: Cardano_Rpc_Node.Client<Transport>

    /// Wraps a client whose connections the caller runs.
    public init(wrapping client: GRPCClient<Transport>) {
        query = .init(wrapping: client)
        submit = .init(wrapping: client)
        sync = .init(wrapping: client)
        watch = .init(wrapping: client)
        node = .init(wrapping: client)
    }
}

/// Connects to `endpoint`, runs `body`, then shuts the connection down.
public func withUTxORPCClient<Result: Sendable>(
    endpoint: UTxORPCEndpoint,
    isolation: isolated (any Actor)? = #isolation,
    _ body: (UTxORPCClient<UTxORPCTransport<HTTP2ClientTransport.Posix>>) async throws -> Result
) async throws -> Result {
    try await withGRPCClient(
        transport: endpoint.makeTransport(),
        interceptors: endpoint.interceptors,
        isolation: isolation
    ) { client in
        try await body(UTxORPCClient(wrapping: client))
    }
}
