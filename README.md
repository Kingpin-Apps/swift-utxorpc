# SwiftUTxORPC

A Swift client for [UTxO RPC](https://utxorpc.org), the gRPC interface to UTxO
blockchains served by cardano-node 11.x, [Dolos](https://github.com/txpipe/dolos)
and [Demeter](https://demeter.run).

## Products

| Product | What it holds |
|---|---|
| `UTxORPC` | Messages and service clients generated from the `utxorpc/v1beta` protos: Query, Submit, Sync, Watch and the Cardano types. |
| `UTxORPCCardanoNode` | cardano-node's own `cardano.rpc.Node` service (`GetEra`, `GetProtocolParamsJson`). |
| `UTxORPCClient` | Connection setup over TCP, TLS or a Unix socket, with API-key headers. |

The package works on wire types only and has no Cardano ledger dependency.
`swift-cardano-chain` maps them to SwiftCardanoCore types.

## Requirements

- macOS 15+, iOS 18+, watchOS 11+, tvOS 18+, visionOS 2+ (set by grpc-swift 2)
- Swift 6.1+

## Usage

```swift
import UTxORPC
import UTxORPCClient

// cardano-node 11.1.x: Unix socket only, next to node.socket.
try await withUTxORPCClient(endpoint: .unixSocket("/path/to/rpc.sock")) { client in
    let tip = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
    print(tip.slot, tip.height)
}

// A hosted server with an API key.
let endpoint = try UTxORPCEndpoint(
    url: URL(string: "https://preview.utxorpc-v0.demeter.run")!,
    headers: ["dmtr-api-key": apiKey]
)
try await withUTxORPCClient(endpoint: endpoint) { client in
    let params = try await client.query.readParams(Utxorpc_V1beta_Query_ReadParamsRequest())
    print(params.values.cardano.maxTxSize)
}
```

Servers implement different parts of the spec. cardano-node never serves the Watch
service, `ReadTx`, `ReadData`, `ReadState` or `DumpHistory`, and its `SearchUtxos`
only accepts exact addresses. Node 11.1.x (cardano-rpc 11.2) also lacks
`ReadEraSummary` and the mempool calls, which node 11.2.0 (cardano-rpc 11.5) adds,
along with TCP and TLS listeners. Missing calls fail with `RPCError` code
`.unimplemented`.

## Protos and code generation

The `.proto` files in `Protos/` are pinned in `Protos/VERSIONS`. The generated
Swift is committed, so consumers need no `protoc`. To regenerate:

```bash
just generate
```

This builds `protoc`, `protoc-gen-swift` and `protoc-gen-grpc-swift-2` from the
versions pinned in `Tools/Package.swift`; no Homebrew tools are used.

## Tests

`swift test` runs the endpoint and in-process server tests. The live tests run
only when the environment names a server:

- `UTXORPC_NODE_SOCKET`: a cardano-node `rpc.sock` (node config `"EnableRpc": true`)
- `UTXORPC_URL`, plus optional `UTXORPC_API_KEY` sent as `dmtr-api-key`

## License

MIT. The vendored protos are Apache-2.0; their licenses are in `Protos/utxorpc/LICENSE`
and `Protos/cardano/LICENSE`.
