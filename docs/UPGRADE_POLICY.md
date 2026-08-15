# Xitcoin V2 upgrade controls

Xitcoin V2 is accessed through the ERC-1967 proxy at `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991`.

The published implementation uses UUPS upgrade authorization. Its source requires unanimous approval from the three configured voter addresses before an implementation upgrade or ownership change can be executed. Approval state is scoped to the proposed action and consumed when the action executes.

The deployed implementation address can change after a valid upgrade; integrations must continue to use the proxy address.

## Read-only verification

```bash
export CRONOS_RPC='https://evm.cronos.org'
export PROXY='0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991'

cast storage "$PROXY"   0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc   --rpc-url "$CRONOS_RPC"
```

The returned storage word contains the current implementation address in its final 20 bytes.
