# Reproduce the local regression campaign

Use Node 24.19.0, npm 11.17.0, Solidity 0.8.30, Foundry 1.3.1 and Echidna 2.2.7.
Install only verified official artifacts; no remote shell installer is required.
Use a disposable checkout, an isolated cache and synthetic local accounts.

```sh
npm ci --ignore-scripts
npm test
forge test
```

`foundry.toml` pins compiler, Paris EVM target, optimizer and a deterministic
512-case fuzz seed. The Hardhat suite also discovers the Solidity regression
suite. No command above selects a remote network.

With pinned crytic-compile 0.4.2 and Slither 0.11.6 in an isolated environment:

```sh
echidna contracts/test/UnauthorizedReleaseHarness.sol \
  --contract UnauthorizedReleaseHarness \
  --config test/echidna/unauthorized.yaml --format text --timeout 90 \
  --crytic-args '--compile-force-framework solc --solc-remaps @openzeppelin/=node_modules/@openzeppelin/' \
  --solc-args '--evm-version paris --optimize'
```

Select a verified Solidity 0.8.30 binary with crytic-compile's `--solc` option.
When Foundry is detected, crytic-compile also needs `forge` on PATH to inspect
configuration. No chain endpoint is needed. The negative-authorization harness
covers duplicate/untrusted signatures, guardian access and unchanged custody;
it is not an authorized-release or full lifecycle campaign.

Observed results: 5 Foundry tests passed (three with 512 fuzz cases each),
29 existing Hardhat tests passed, and all 3 Echidna properties passed after
10,001 generated calls with seed 20260905. A separate bounded Mythril 0.24.8
runtime-only scan raised an unconfirmed requirement-violation alert on a getter
path with uninitialized constructor/immutable state. It is not evidence of an
exploitable vault flaw. No quantitative full-contract coverage or formal proof
is claimed.
