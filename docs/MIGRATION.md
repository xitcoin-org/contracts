# Xitcoin V1 to V2 migration

## Purpose

The migration contract converts legacy Xitcoin V1 balances on Cronos into Xitcoin V2 balances. It does not bridge assets to Xitcoin EVM.

## Accounting

V1 uses 8 decimals and V2 uses 18 decimals. For an input of `amount` V1 atomic units, the contract calculates:

```text
v2Amount = amount × 10^(18 - 8)
```

This preserves the displayed token amount across the decimal change.

During `swapTokens(amount)`:

1. V1 is transferred from the caller to the migration contract.
2. The same V1 amount is transferred to `0x000000000000000000000000000000000000dEaD`.
3. The normalized V2 amount is transferred from the migration reserve to the caller.
4. `SwapExecuted` is emitted.

A transfer to the dead address is not a token burn unless the V1 contract itself reduces `totalSupply`. The migration flow therefore removes V1 from practical circulation but does not claim that V1 `totalSupply` decreases.

## Read-only verification

```bash
export CRONOS_RPC='https://evm.cronos.org'
export V1='0xDD646291D2fff52c75F27CCDAdD0D4C2A24f37Dd'
export V2='0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991'
export MIGRATION='0x5A570197e4835d0c2F2F956026981E0cff50A8c9'

cast call "$V1" 'decimals()(uint8)' --rpc-url "$CRONOS_RPC"
cast call "$V2" 'decimals()(uint8)' --rpc-url "$CRONOS_RPC"
cast call "$MIGRATION" 'fromToken()(address)' --rpc-url "$CRONOS_RPC"
cast call "$MIGRATION" 'toToken()(address)' --rpc-url "$CRONOS_RPC"
```

These commands do not submit transactions.
