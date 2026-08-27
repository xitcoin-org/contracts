# Cronos UUPS control verification — 27 August 2026

## Scope

Read-only verification of the upgrade authority for the Xitcoin V2 proxy on Cronos Mainnet. No transaction, signature, vote or contract change was performed.

## Verified deployment state

| Field | Verified value |
|---|---|
| Network | Cronos Mainnet |
| Chain ID | `25` (`0x19`) |
| Reference block | `90391385` |
| Proxy | `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991` |
| ERC-1967 implementation | `0x6c171952999421f0da00e14f97b9c2dfbe71d8a0` |
| ERC-20 owner | `0x9583485cefdac14a49b543ef06006e33cca3150a` |
| Pending upgrade | zero address |
| Voter 1 | `0x75afa58484b105a0d5fd8591dd6931c50494ad9c` |
| Voter 2 | `0xd5692c2f7d7e41476bcc73182ef9f6ac325dabca` |
| Voter 3 | `0xa952f19f3653173104fd99efe2db451cd26cc82d` |

The three voter addresses returned empty runtime bytecode at the reference block and are therefore externally owned accounts at that state.

## Authorization result

The active canonical source implements UUPS authorization through an internal state flag:

- only a configured voter may call `voteToUpgrade(address)`;
- all three distinct voters must approve the same implementation;
- the third vote sets the internal upgrade-in-progress flag and invokes `upgradeToAndCall`;
- `_authorizeUpgrade` accepts only that internal execution and only the recorded pending implementation;
- the ERC-20 owner cannot authorize an upgrade independently;
- direct external calls to `upgradeToAndCall` are rejected;
- the current threshold is unanimous **3-of-3**, not 2-of-3.

The same three-voter unanimity controls owner changes through `voteToChangeOwner(address)`.

## Source and registry evidence

- canonical source: `contracts/cronos/v2/XTCV2.sol`;
- canonical source SHA-256: `b5de4f5c4f13334bf644ec8fa97f8b0cda836ddc76935dc14c7bfcda2a73ff14`;
- the locally recalculated source hash matched the deployment and Cyberscope records;
- the implementation read from the ERC-1967 slot matched `deployments/cronos.json`;
- production dependency audit reported zero vulnerabilities;
- repository CI and code scanning on current `main` were successful.

This verification does not claim that a future implementation has been audited.

## Blocking conditions before any upgrade

1. Prove controlled access to all three voter keys without exposing private material.
2. Prepare a storage-layout-compatible implementation.
3. Preserve proxy address, balances, allowances, decimals and total supply.
4. Make the intended metadata change deterministic at upgrade execution.
5. Compile, test, statically analyze and independently review the exact release source and bytecode.
6. Publish the implementation address, source hash, bytecode evidence, execution order and rollback limitations.
7. Simulate the complete three-vote process on a fork and a test environment.
8. Execute no production vote until every preceding condition is closed.

## Operational risk

With the current unanimous threshold, loss or compromise response affecting any one voter key can prevent future upgrades and owner changes. Key custody and recoverability must be verified before a symbol-normalization implementation is prepared for production.
