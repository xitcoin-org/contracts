# Xitcoin on Cronos

This directory records public discovery and verification references for the current Xitcoin V2 token on Cronos Mainnet.

## Canonical identity

| Field | Value |
|---|---|
| Network | Cronos Mainnet |
| Chain ID | `25` |
| Asset | Xitcoin |
| Public ticker | `XTC` |
| V2 proxy | `0xE45FE733BC8617FA6DAC8437FC44B5FFFA949991` |
| Decimals | `18` |

Applications must use the V2 proxy address. The source and deployment registry remain authoritative for contract integration.

## Verification and listings

- [Cronos Explorer token profile](https://explorer.cronos.com/token/0xe45fe733bc8617fa6dac8437fc44b5fffa949991)
- [Cronos Explorer contract](https://explorer.cronos.com/address/0xe45fe733bc8617fa6dac8437fc44b5fffa949991)
- [CoinGecko](https://www.coingecko.com/en/coins/xitcoin) — API identifier: `xitcoin`
- [CoinMarketCap](https://coinmarketcap.com/currencies/xitcoin/) — asset identifier: `39608`

These third-party pages are discovery references. Contract identity must always be confirmed against the proxy address above.

## Markets

CoinGecko currently indexes Xitcoin V2 markets on VVS V3 (Cronos), Obsidian Finance and Ebisu's Bay. Market availability, liquidity, volume and routing are dynamic third-party data.

The repository therefore does not designate a trading pair as an official pool and does not publish mutable market statistics. Use the [CoinGecko markets table](https://www.coingecko.com/en/coins/xitcoin#markets) for current discovery, then verify that the route uses the V2 proxy address before signing.

## Machine-readable reference

`cronos.json` contains stable identifiers and discovery URLs. It intentionally excludes prices, volumes, liquidity balances and unverified pool addresses.
