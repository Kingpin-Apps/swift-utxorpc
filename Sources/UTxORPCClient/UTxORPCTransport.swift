import GRPCCore

/// The UTxO RPC API version a server speaks.
public enum UTxORPCAPIVersion: String, Sendable, Hashable, CaseIterable {
    /// The current API, served by cardano-node, Dolos, Demeter and Dingo.
    case v1beta
    /// The older API, the only one cardano-node-api serves.
    case v1alpha
}

/// A transport that sends the v1beta clients' calls to the services of the API
/// version the server speaks.
///
/// v1alpha's messages share v1beta's field numbers and types, so the v1beta
/// clients read and write them unchanged, with two gaps in parsed blocks and
/// transactions:
/// - A v1alpha mint quantity (`Asset.mint_coin`) reads as 0. Output quantities
///   read correctly.
/// - v1alpha puts redeemers on `Multiasset` and `TxInput` only, so
///   `WitnessSet.redeemers` is empty.
///
/// Native CBOR (`AnyUtxoData.nativeBytes`, `AnyChainBlock.nativeBytes`) is
/// unaffected. For exact v1alpha fields, use the `UTxORPCV1Alpha` clients.
/// Calls to services outside `utxorpc.v1beta`, such as cardano-node's own
/// `cardano.rpc.Node`, pass through unchanged.
public struct UTxORPCTransport<Base: ClientTransport>: ClientTransport {
    public typealias Bytes = Base.Bytes

    public let base: Base
    public let apiVersion: UTxORPCAPIVersion

    public init(wrapping base: Base, apiVersion: UTxORPCAPIVersion) {
        self.base = base
        self.apiVersion = apiVersion
    }

    public var retryThrottle: RetryThrottle? { base.retryThrottle }

    public func connect() async throws {
        try await base.connect()
    }

    public func beginGracefulShutdown() {
        base.beginGracefulShutdown()
    }

    public func withStream<T: Sendable>(
        descriptor: MethodDescriptor,
        options: CallOptions,
        _ closure: (_ stream: RPCStream<Inbound, Outbound>, _ context: ClientContext) async throws -> T
    ) async throws -> T {
        try await base.withStream(descriptor: route(descriptor), options: options, closure)
    }

    public func config(forMethod descriptor: MethodDescriptor) -> MethodConfig? {
        base.config(forMethod: route(descriptor))
    }

    /// The method `descriptor` names on a server speaking ``apiVersion``.
    func route(_ descriptor: MethodDescriptor) -> MethodDescriptor {
        let prefix = "utxorpc.v1beta."
        let service = descriptor.service.fullyQualifiedService
        guard apiVersion != .v1beta, service.hasPrefix(prefix) else { return descriptor }
        return MethodDescriptor(
            fullyQualifiedService: "utxorpc.\(apiVersion.rawValue)." + service.dropFirst(prefix.count),
            method: descriptor.method,
            type: descriptor.type
        )
    }
}
