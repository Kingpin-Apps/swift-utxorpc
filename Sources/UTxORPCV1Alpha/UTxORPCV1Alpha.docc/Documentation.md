# ``UTxORPCV1Alpha``

Messages and service clients for the older UTxO RPC v1alpha API.

## Overview

v1alpha came before v1beta. Most servers have moved on, but cardano-node-api still speaks
only v1alpha. The types follow the same naming as the `UTxORPC` module, with `V1alpha`
in place of `V1beta`: `Utxorpc_V1alpha_Query_QueryService`, `Utxorpc_V1alpha_Cardano_PParams`.

You usually don't need this module. An endpoint with `apiVersion: .v1alpha` in
`UTxORPCClient` sends the v1beta clients' calls to a v1alpha server, because the two APIs
share field numbers and types. Use these clients directly when you need the fields that
differ:

- Mint quantities, which v1alpha keeps in `Asset.mintCoin`.
- Redeemers, which v1alpha puts on `Multiasset` and `TxInput` instead of the witness set.

The protos are spec tag v0.19.2's `utxorpc/v1alpha`, without its Bitcoin package.

## Topics

### Services

- ``Utxorpc_V1alpha_Query_QueryService``
- ``Utxorpc_V1alpha_Submit_SubmitService``
- ``Utxorpc_V1alpha_Sync_SyncService``
- ``Utxorpc_V1alpha_Watch_WatchService``

### Common messages

- ``Utxorpc_V1alpha_Sync_BlockRef``
- ``Utxorpc_V1alpha_Query_AnyUtxoData``
- ``Utxorpc_V1alpha_Cardano_PParams``
