# Connecting to servers

Describe where a server listens, then make calls for one block of work or over a connection
you keep.

## Overview

A ``UTxORPCEndpoint`` says where the server is, whether to use TLS, which headers to send on
every call, and which API version the server speaks.

### A local cardano-node

cardano-node 11.x serves UTxO RPC when its config has `"EnableRpc": true`. Node 11.1.x listens
only on a Unix socket, `rpc.sock`, next to `node.socket`:

```swift
let endpoint = UTxORPCEndpoint.unixSocket("/opt/cardano/mainnet/socket/rpc.sock")
```

### A hosted server

Give ``UTxORPCEndpoint/init(url:headers:apiVersion:)`` a URL:

- `https://host[:port]` connects over TLS, on port 443 by default.
- `http://host[:port]` connects in plaintext, on port 80 by default.
- `unix:///path/to/rpc.sock` connects to a Unix socket.

Hosted providers usually want an API key header. Demeter's is `dmtr-api-key`:

```swift
let endpoint = try UTxORPCEndpoint(
    url: URL(string: "https://cardano-mainnet.utxorpc-m1.demeter.run")!,
    headers: ["dmtr-api-key": apiKey]
)
```

Keep API keys out of source code; read them from the environment or the Keychain.

### One block of calls

``withUTxORPCClient(endpoint:isolation:_:)`` connects, runs your closure with a
``UTxORPCClient/UTxORPCClient``, and closes the connection when the closure returns:

```swift
let params = try await withUTxORPCClient(endpoint: endpoint) { client in
    try await client.query.readParams(Utxorpc_V1beta_Query_ReadParamsRequest())
}
print(params.values.cardano.maxTxSize)
```

### A connection you keep

Each new connection costs a round trip, and over TLS a handshake as well. To make many calls,
keep a ``UTxORPCConnection``. It connects on the first call, reconnects on its own if the
server goes away, and shares one HTTP/2 connection between all calls. Against Demeter, ten
`ReadTip` calls took 1.5 s over one connection and 5.7 s with a connection each.

```swift
let connection = try UTxORPCConnection(endpoint: endpoint)
let tip = try await connection.client.sync.readTip(Utxorpc_V1beta_Sync_ReadTipRequest())
// ...
await connection.close()
```

### Building requests

The generated messages are value types with a `with` builder:

```swift
let page = try await client.query.searchUtxos(.with {
    $0.predicate.match.cardano.address.exactAddress = addressBytes
    $0.maxItems = 100
})
for item in page.items {
    print(item.txoRef.hash, item.txoRef.index, item.nativeBytes.count)
}
```

A call the server doesn't implement throws `RPCError` with code `.unimplemented`. See
<doc:Server-Differences> for what each server answers.
