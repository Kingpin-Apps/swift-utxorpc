# Server differences

What each UTxO RPC server implements, and where their answers differ on the wire.

## Overview

Servers implement different parts of the specification, and the specification leaves some
units open. A call a server lacks throws `RPCError` with code `.unimplemented`, so a client
can fall back to another source.

### cardano-node

cardano-node serves a live view of its ledger. It is not a chain index, so it never answers
the Watch service, `ReadTx`, `ReadData`, `ReadState` or `DumpHistory`.

- `SearchUtxos` accepts only an exact address, or `anyOf` exact addresses. It scans the whole
  UTxO set, so on mainnet a search takes seconds.
- `ReadGenesis.genesis` is the 32-byte hash of the Shelley genesis file. The parameters are
  in its `cardano` field.
- `Genesis.slot_length` is in milliseconds.
- Node 11.1.x (cardano-rpc 11.2) listens only on a Unix socket and has no reflection,
  `ReadEraSummary` or mempool calls. Node 11.2.0 (cardano-rpc 11.5) adds TCP and TLS
  listeners, reflection, `ReadEraSummary`, `ReadMempool` and `WatchMempool`.
- Only the node serves `cardano.rpc.Node`, in the `UTxORPCCardanoNode` module.

### Dolos and Demeter

Demeter's UTxO RPC runs on Dolos.

- It answers `ReadTx`, `EvalTx`, `ReadEraSummary` and `DumpHistory`.
- `Genesis.slot_length` is in whole seconds, where the node sends milliseconds.
- The tip's `height` is always 0.
- The era summary is split at forks inside an era, so some eras appear twice.
- `EvalTx` checks the transaction's ledger rules before running its scripts, so it rejects a
  transaction that isn't signed yet (`VKWitnessMissing`).

### cardano-node-api (v1alpha)

cardano-node-api speaks only the older v1alpha API. Set the endpoint's API version and use
the same v1beta clients:

```swift
let endpoint = try UTxORPCEndpoint(
    url: URL(string: "http://127.0.0.1:9090")!,
    apiVersion: .v1alpha
)
```

``UTxORPCTransport`` sends each call to the matching `utxorpc.v1alpha` service. The v1alpha
messages use the same field numbers and types as v1beta, so they decode unchanged, with two
gaps in parsed blocks and transactions:

- v1alpha mint quantities read as 0.
- v1alpha redeemers are not in `WitnessSet.redeemers`.

Native CBOR (`nativeBytes`) is unaffected. For the exact v1alpha fields, use the clients in
`UTxORPCV1Alpha` directly.

cardano-node-api has no `ReadGenesis`, `ReadEraSummary`, `ReadTx`, `ReadData` or `EvalTx`,
and its `FetchBlock` returns no blocks. Its `ReadParams` leaves out the Conway governance
parameters. In its last release (0.10.1) the cost models are also shifted by one: the
PlutusV2 model arrives as V1 and V3 as V2.
