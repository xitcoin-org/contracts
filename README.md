# Xitcoin Contracts

Canonical source and deployment references for Xitcoin smart contracts.

## Cronos deployments

| Component | Address | Decimals | Purpose |
|---|---|---:|---|
| Xitcoin V1 | `0xDD646291D2fff52c75F27CCDAdD0D4C2A24f37Dd` | 8 | Legacy fixed-supply token |
| Xitcoin V2 proxy | `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991` | 18 | Current upgradeable token entry point |
| Xitcoin V2 implementation | `0x6c171952999421F0DA00E14F97B9C2DfBE71D8A0` | 18 | Current proxy implementation |
| Migration | `0x5A570197e4835d0c2F2F956026981E0cff50A8c9` | — | Converts V1 units to V2 units |

Use the proxy address for all V2 integrations. Addresses are also published in [`deployments/cronos.json`](deployments/cronos.json).

## Repository layout

- `contracts/cronos/v1/`: verified V1 source;
- `contracts/cronos/v2/`: verified V2 implementation source;
- `contracts/cronos/migration/`: verified migration source;
- `deployments/`: machine-readable deployment registry;
- `docs/MIGRATION.md`: migration accounting and verification;
- `docs/UPGRADE_POLICY.md`: V2 upgrade controls.

The native XTC asset on Xitcoin EVM is implemented by the chain and is not an ERC-20 deployment in this repository. A future cross-chain bridge contract will be published here only after implementation, review and deployment.

## Verification

```bash
sha256sum contracts/cronos/v1/XitcoinV1.sol
sha256sum contracts/cronos/v2/XTCV2.sol
sha256sum contracts/cronos/migration/Migration.sol
jq . deployments/cronos.json
```

Expected source hashes are recorded in `deployments/cronos.json`.

## Security

Do not send assets to an address copied from an untrusted source. Verify the chain, address and intended function against the registry and the Cronos explorer before signing.

Report vulnerabilities privately according to [`SECURITY.md`](SECURITY.md).
