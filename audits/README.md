# Independent audits

## Xitcoin V2 implementation

| Field | Value |
|---|---|
| Auditor | Cyberscope |
| Report | https://www.cyberscope.io/audits/1-xtc |
| Network | Cronos Mainnet |
| Proxy | `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991` |
| Audited source label | `XitcoinV3_cyberscope.sol` |
| Canonical repository source | `contracts/cronos/v2/XTCV2.sol` |
| SHA-256 | `b5de4f5c4f13334bf644ec8fa97f8b0cda836ddc76935dc14c7bfcda2a73ff14` |

The auditor's historical filename and the repository filename differ, but the full source hash identifies the same source code. The deployed verified implementation contract is named `XitcoinImplementation`.

## Scope

This reference covers only the source identified by the hash above. It must not be interpreted as an audit of:

- Xitcoin V1;
- the V1-to-V2 migration contract;
- the Xitcoin EVM chain;
- validator, bridge or explorer infrastructure;
- future implementations or upgrades.

After a proxy upgrade, the active implementation address and source hash must be checked again before relying on this audit.
