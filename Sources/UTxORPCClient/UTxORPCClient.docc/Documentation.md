# ``UTxORPCClient``

Connect to a UTxO RPC server over TCP, TLS or a Unix socket, and call its services.

## Overview

[UTxO RPC](https://utxorpc.org) is a gRPC interface to UTxO blockchains. On Cardano it is
served by cardano-node 11.x itself, by [Dolos](https://github.com/txpipe/dolos), by hosted
providers such as [Demeter](https://demeter.run), and by cardano-node-api.

This module sets up the connection. The messages and service clients it hands you are
generated from the protocol's `.proto` files and live in `UTxORPC` (the current v1beta API),
`UTxORPCV1Alpha` (the older v1alpha API) and `UTxORPCCardanoNode` (cardano-node's own
`cardano.rpc.Node` service).

```swift
import UTxORPC
import UTxORPCClient

try await withUTxORPCClient(endpoint: .unixSocket("/opt/cardano/mainnet/socket/rpc.sock")) { client in
    let tip = try await client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest()).tip
    print(tip.slot, tip.height)
}
```

The package works on wire types only and has no Cardano ledger dependency. To turn these
messages into ledger types, such as protocol parameters and UTxOs, use the
`UTxORPCChainContext` in swift-cardano-chain.

## Topics

### Essentials

- <doc:Connecting-To-Servers>
- <doc:Server-Differences>

### Connecting

- ``UTxORPCEndpoint``
- ``withUTxORPCClient(endpoint:isolation:_:)``
- ``UTxORPCConnection``
- ``UTxORPCClient/UTxORPCClient``

### API versions

- ``UTxORPCAPIVersion``
- ``UTxORPCTransport``

### Errors

- ``UTxORPCClientError``
