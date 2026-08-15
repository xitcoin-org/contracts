# Xitcoin Token Upgrade Policy

## Scope

This policy applies to the canonical XTC proxy on Cronos:

`0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991`

## Governance model

The token uses the UUPS proxy pattern. The published implementation requires approval from all three configured voter addresses before an implementation upgrade or ownership change can execute.

The proxy address remains the canonical integration address. Implementation addresses are version-specific and must not be treated as token addresses.

## Release requirements

A production upgrade must include:

1. reviewed source changes on a dedicated branch;
2. reproducible compiler and dependency settings;
3. storage-layout and UUPS compatibility checks;
4. unit, integration and fork tests covering the affected behavior;
5. security review proportionate to the change;
6. verified implementation source on the target explorer;
7. all approvals required by the on-chain governance mechanism;
8. a release record containing the implementation address, source revision and verification reference.

## Verification

Before approving an upgrade, reviewers must compare the proposed implementation with the verified source and confirm the active proxy implementation:

```bash
export CRONOS_RPC='https://evm.cronos.org'
export XTC_PROXY='0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991'

cast implementation "$XTC_PROXY" --rpc-url "$CRONOS_RPC"
cast code "$XTC_PROXY" --rpc-url "$CRONOS_RPC" | sha256sum
```

## Emergency handling

The current implementation does not expose a general-purpose pause function. An incident response must first determine whether action is possible under the deployed contract's existing controls. Any new emergency mechanism requires explicit design review, testing and independent security assessment.

## Bridge separation

Bridge routes use dedicated contracts and accounting controls. Bridge support must not depend on changing the canonical token proxy unless a separately reviewed token upgrade is strictly required.
