# Cronos bridge vault

## Purpose

`CronosBridgeVault` is the Cronos custody component of the canonical XTC route between Cronos and Xitcoin.

- Cronos to Xitcoin: a holder deposits canonical Cronos XTC into the vault. The corresponding native XTC settlement is performed by the Xitcoin bridge after its independent attestation checks.
- Xitcoin to Cronos: native XTC is burned on Xitcoin. The vault releases the corresponding locked Cronos XTC after two current bridge signers approve the burn record.

The vault does not mint or burn the Cronos token. Sending XTC to a dead address is not a bridge operation and does not reduce ERC-20 `totalSupply`.

## Canonical asset

Production construction must use the Xitcoin V2 proxy, not its implementation address:

```text
0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991
```

The implementation address may change through the independently governed UUPS upgrade process. The proxy is the stable integration address.

## Security model

- every release is bound by EIP-712 to the Cronos chain ID and the deployed vault address;
- every release identifies one native Xitcoin burn and that identifier can be processed only once;
- two distinct approvals from the current three-member signer set are required;
- signer-set versions prevent approvals from silently crossing a signer rotation;
- signatures expire;
- per-release and daily limits cap exposure;
- releases cannot exceed the vault's actual XTC balance;
- deposits and releases reject the zero and conventional dead addresses;
- the emergency guardian can pause immediately but cannot resume the vault;
- resumption, signer rotation, limit changes and guardian changes require signer quorum and a monotonic governance nonce;
- no owner or administrative withdrawal of canonical XTC exists;
- a quorum-controlled rescue is restricted to unrelated ERC-20 assets.

The signer service must approve a release only after independently confirming finality, the native burn amount, the recipient, the route, the signer-set version and the absence of an earlier approval for the same burn identifier.

## Build and tests

The project deliberately uses two Solidity compilers:

- `0.8.4` for the exact historical V1 source;
- `0.8.30` with EVM target `paris` for V2 and the vault.

```bash
npm ci
npm run audit:production
npm run compile
npm run test:vault
```

The package lock is authoritative. Do not apply an automated breaking dependency rewrite to deployment tooling.

## Deployment controls

Deployment is a separate reviewed operation. Before any Cronos transaction:

1. confirm the canonical V2 proxy from `deployments/cronos.json` and the Cronos Explorer;
2. define three distinct bridge signer addresses and a separate guardian;
3. define conservative initial release limits;
4. derive and record the route identifier;
5. reproduce the build from `package-lock.json`;
6. test construction on Cronos testnet;
7. verify the exact source and constructor arguments in Cronos Explorer;
8. perform deposits and releases with low-value test assets before considering a production route.

No private key, mnemonic, API key or RPC credential belongs in this repository.

## Explorer verification

Current Cronos Explorer endpoints are tracked separately from compilation because explorer APIs can change independently of contract source:

```text
Mainnet explorer: https://explorer.cronos.com
Mainnet API:      https://explorer-api.cronos.org/mainnet/api/v2
Testnet explorer: https://explorer.cronos.com/testnet
Testnet API:      https://explorer-api.cronos.org/testnet/api/v2
```

At deployment time, use the current supported Hardhat verification configuration and keep the explorer API key in an environment variable. If automated multi-source verification is rejected by the Explorer API, submit the identical standard compiler input through the Explorer interface and record the verified address and source hash in `deployments/cronos.json`.

No deployment address is canonical until it appears in the deployment registry on the default branch.
