# Xitcoin on Cronos

This directory records stable public discovery, verification and community references for the current Xitcoin V2 token on Cronos Mainnet.

## Canonical identity

| Field | Value |
|---|---|
| Network | Cronos Mainnet |
| Chain ID | `25` |
| Asset | Xitcoin |
| On-chain V2 `symbol()` | `$XTC` |
| Public asset notation | `XTC` |
| V2 proxy | `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991` |
| Decimals | `18` |

The dollar sign is part of the deployed Cronos V2 contract's historical `symbol()` value. It is not part of the native Xitcoin blockchain denomination, whose public symbol is `XTC` and atomic denomination is `axtc`.

Applications integrating the Cronos token must use the V2 proxy address and must tolerate the exact on-chain symbol. The source and deployment registry remain authoritative for contract integration.

## Verification and listings

- [Cronos Explorer token profile](https://explorer.cronos.com/token/0xe45fe733bc8617fa6dac8437fc44b5fffa949991)
- [Cronos Explorer contract](https://explorer.cronos.com/address/0xe45fe733bc8617fa6dac8437fc44b5fffa949991)
- [Cyberscope project profile](https://www.cyberscope.io/audits/1-xtc)
- [CoinGecko](https://www.coingecko.com/en/coins/xitcoin) — API identifier: `xitcoin`
- [CoinMarketCap](https://coinmarketcap.com/currencies/xitcoin/) — asset identifier: `39608`

The smart-contract audit scope and the external KYC record are documented separately in [`audits/`](../audits/) and [`verification/`](../verification/). Third-party pages are discovery references; contract identity must always be confirmed against the proxy address above.

## Official community channels

- [X / Twitter](https://x.com/Xitcoin_org)
- [Telegram](https://t.me/xitcoin_org)
- [Discord](https://discord.gg/wFrHx3tAD8)

Only stable, verified channel URLs are recorded. Follower counts, member counts, scores and rankings are intentionally excluded because they change independently of this repository.

## Markets

CoinGecko currently indexes Xitcoin V2 markets on VVS V3 (Cronos), Obsidian Finance and Ebisu's Bay. Market availability, liquidity, volume and routing are dynamic third-party data.

The repository therefore does not designate a trading pair as an official pool and does not publish mutable market statistics. Use the [CoinGecko markets table](https://www.coingecko.com/en/coins/xitcoin#markets) for current discovery, then verify that the route uses the V2 proxy address before signing.

## Machine-readable reference

`cronos.json` contains stable identifiers and URLs. It intentionally excludes prices, volumes, liquidity balances, audience statistics and unverified pool addresses.
