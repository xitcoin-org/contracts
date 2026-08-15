# Xitcoin Smart Contracts

Canonical contract references and verified source archives for Xitcoin (XTC).

## Cronos token

| Property | Value |
| --- | --- |
| Network | Cronos EVM |
| Proxy | [`0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991`](https://explorer.cronos.org/address/0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991) |
| Current implementation | [`0x6c171952999421f0da00e14f97b9c2dfbe71d8a0`](https://explorer.cronos.org/address/0x6c171952999421f0da00e14f97b9c2dfbe71d8a0#code) |
| Architecture | ERC-20, UUPS proxy |
| Decimals | 18 |

The proxy address is the canonical XTC address on Cronos. Integrations must use the proxy rather than an implementation address.

## Source archive

The verified implementation source is archived at [`contracts/XitcoinV3.sol`](contracts/XitcoinV3.sol).

- Audit: [Cyberscope Xitcoin audit](https://cyberscope.io/audits/1-xtc)
- Source SHA-256: `270dfcdc22f5300c2534432c994122ee1b67fb397445d431a7099c16d97688a6`
- License: MIT

Verify the archived file:

```bash
sha256sum contracts/XitcoinV3.sol
```

## Read-only contract checks

The following commands require [Foundry](https://book.getfoundry.sh/getting-started/installation) and a Cronos RPC endpoint:

```bash
export CRONOS_RPC='https://evm.cronos.org'
export XTC_PROXY='0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991'

cast call "$XTC_PROXY" 'name()(string)' --rpc-url "$CRONOS_RPC"
cast call "$XTC_PROXY" 'symbol()(string)' --rpc-url "$CRONOS_RPC"
cast call "$XTC_PROXY" 'decimals()(uint8)' --rpc-url "$CRONOS_RPC"
cast call "$XTC_PROXY" 'totalSupply()(uint256)' --rpc-url "$CRONOS_RPC"
cast implementation "$XTC_PROXY" --rpc-url "$CRONOS_RPC"
```

These calls are read-only and do not request approvals or submit transactions.

## Supply reduction

The current implementation exposes an owner-only `burn(uint256)` function. A successful burn reduces the caller's balance and ERC-20 `totalSupply`. Sending tokens to a dead address is a transfer and does not, by itself, reduce `totalSupply`.

## Upgrade governance

Contract upgrades follow the controls in [`docs/UPGRADE_POLICY.md`](docs/UPGRADE_POLICY.md). Security reports follow [`SECURITY.md`](SECURITY.md).
