# Xitcoin Contracts

Canonical source, deployment, security and ecosystem references for Xitcoin smart contracts.

## Cronos deployments

| Component | Address | Decimals | Purpose |
|---|---|---:|---|
| Xitcoin V1 | `0xDD646291D2fff52c75F27CCDAdD0D4C2A24f37Dd` | 8 | Legacy fixed-supply token |
| Xitcoin V2 proxy | `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991` | 18 | Current upgradeable token entry point |
| Xitcoin V2 implementation | `0x6c171952999421F0DA00E14F97B9C2DfBE71D8A0` | 18 | Current proxy implementation |
| Migration | `0x5A570197e4835d0c2F2F956026981E0cff50A8c9` | — | Converts V1 units to V2 units |

Use the proxy address for integrations with Xitcoin V2. The machine-readable deployment registry is [`deployments/cronos.json`](deployments/cronos.json).

## Repository layout

- `contracts/cronos/v1/`: verified V1 source;
- `contracts/cronos/v2/`: verified V2 implementation source;
- `contracts/cronos/migration/`: verified migration source;
- `deployments/`: canonical network and contract registry;
- `audits/`: independent smart-contract audit records and exact source scope;
- `verification/`: external project verification and KYC references;
- `ecosystem/`: explorer verification, listings, markets and official community channels;
- `docs/MIGRATION.md`: migration accounting and verification;
- `docs/UPGRADE_POLICY.md`: V2 upgrade controls.

The native XTC asset on Xitcoin EVM is implemented by the chain. It is not an ERC-20 deployment in this repository. A cross-chain bridge contract will be published here only after it exists, has been reviewed and has a canonical deployment.

## Audit and external verification

The current V2 implementation source is covered by the Cyberscope audit referenced in [`audits/README.md`](audits/README.md). The audited SHA-256 matches `contracts/cronos/v2/XTCV2.sol`.

Cyberscope's project profile and KYC record are indexed separately in [`verification/README.md`](verification/README.md). KYC confirms an identity-verification result; it does not expand smart-contract audit scope.

No audit coverage is claimed here for V1, the migration contract, Xitcoin EVM or a future bridge unless an explicit report is added with a matching source hash.

## Verification, listings and community

Cronos Explorer verification, CoinGecko, CoinMarketCap, current market-discovery references and official community channels are maintained in [`ecosystem/README.md`](ecosystem/README.md). Third-party markets are not designated as official pools. Always verify the Cronos chain and V2 proxy address before signing.

## Verification commands

```bash
sha256sum contracts/cronos/v1/XitcoinV1.sol
sha256sum contracts/cronos/v2/XTCV2.sol
sha256sum contracts/cronos/migration/Migration.sol
jq . deployments/cronos.json
jq . ecosystem/cronos.json
```

Expected source hashes are recorded in `deployments/cronos.json`.

## Security

Verify the chain, address and intended function before signing. Report vulnerabilities privately according to [`SECURITY.md`](SECURITY.md).
