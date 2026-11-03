# ``UTxORPC``

Messages and service clients for UTxO RPC v1beta, generated from the protocol's `.proto` files.

## Overview

Each `.proto` package becomes a Swift prefix: `utxorpc.v1beta.query` becomes
`Utxorpc_V1beta_Query_`, and `utxorpc.v1beta.cardano` becomes `Utxorpc_V1beta_Cardano_`.
Each service is an enum with a `Client` you call and protocols you implement to serve it.

To connect to a server, use the `UTxORPCClient` module, which hands you these clients over
TCP, TLS or a Unix socket. Messages are built with `with`:

```swift
let request = Utxorpc_V1beta_Query_SearchUtxosRequest.with {
    $0.predicate.match.cardano.address.exactAddress = addressBytes
    $0.maxItems = 100
}
```

Chain-specific data sits in a `oneof` named after the chain. Read the Cardano case either
through its accessor or by matching:

```swift
let maxTxSize = response.values.cardano.maxTxSize
if case .cardano(let params)? = response.values.params { print(params.maxTxSize) }
```

Most Cardano messages also carry the original CBOR as `nativeBytes`. Decoding that with a
ledger library is more exact than reading the parsed fields.

The protos are pinned in `Protos/VERSIONS`: cardano-rpc 11.5.0.0's copy of the v1beta
protos, which is spec v0.19.2 with `EvalReport.purpose` and `index` made optional, and the
spec's own `watch.proto`.

## Topics

### Services

- ``Utxorpc_V1beta_Query_QueryService``
- ``Utxorpc_V1beta_Submit_SubmitService``
- ``Utxorpc_V1beta_Sync_SyncService``
- ``Utxorpc_V1beta_Watch_WatchService``

### Chain state

- ``Utxorpc_V1beta_Sync_BlockRef``
- ``Utxorpc_V1beta_Query_ChainPoint``
- ``Utxorpc_V1beta_Cardano_PParams``
- ``Utxorpc_V1beta_Cardano_Genesis``

### UTxOs

- ``Utxorpc_V1beta_Query_TxoRef``
- ``Utxorpc_V1beta_Query_AnyUtxoData``
- ``Utxorpc_V1beta_Query_UtxoPredicate``
- ``Utxorpc_V1beta_Cardano_TxOutput``

### Blocks and transactions

- ``Utxorpc_V1beta_Sync_AnyChainBlock``
- ``Utxorpc_V1beta_Cardano_Block``
- ``Utxorpc_V1beta_Cardano_Tx``
- ``Utxorpc_V1beta_Cardano_TxEval``
