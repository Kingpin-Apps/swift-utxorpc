# ``UTxORPCCardanoNode``

cardano-node's own `cardano.rpc.Node` service, served next to UTxO RPC.

## Overview

cardano-node 11.x serves this small service alongside UTxO RPC, on the same socket or
port. Other servers don't have it, and a call to them throws `RPCError` with code
`.unimplemented`.

- `GetEra` returns the node's current era.
- `GetProtocolParamsJson` returns the protocol parameters as the node's own JSON, the same
  shape `cardano-cli query protocol-parameters` prints.

```swift
try await withUTxORPCClient(endpoint: .unixSocket("/opt/cardano/mainnet/socket/rpc.sock")) { client in
    let era = try await client.node.getEra(Google_Protobuf_Empty()).era
    let json = try await client.node.getProtocolParamsJson(Google_Protobuf_Empty()).json
}
```

The proto is cardano-rpc 11.5.0.0's `node.proto`.

## Topics

### Service

- ``Cardano_Rpc_Node``

### Messages

- ``Cardano_Rpc_CurrentEra``
- ``Cardano_Rpc_Era``
- ``Cardano_Rpc_ProtocolParamsJson``
