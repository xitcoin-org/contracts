# Conditional release-accounting finding

Internal INO review of xitcoin-org/contracts at
`d3ae7058d4c6697a9ec079864e1891b661de5b3e`; 5 September 2026.
Severity: **Medium, conditional on nonstandard or changed bound-token behavior**.
No claim is made that the current canonical asset exhibits this behavior.

The vault checked the boolean success of a token transfer but not exact delivery
before committing its burn marker and Released event. A token returning success
without movement, or applying a transfer fee, can therefore consume a release
without delivering the approved quantity. This assumes control over, or a change
to, the bound token implementation; it is not an unauthorized-signature bypass.

The proposed correction checks both vault debit and recipient credit. A mismatch
reverts the transaction, including the replay marker, daily accounting and token
side effects. It does not authenticate a token that lies about its balances or
protect against arbitrary malicious token implementations. Future deployments
must still bind a reviewed token implementation and its upgrade authority.

Pinned Foundry 1.3.1 with Solidity 0.8.30 reproduced the failed atomicity test
before correction. The harness also checks unsigned attempts, pause, replay,
ordinary conservation and callback reentrancy. Fuzz inputs use a fixed seed and
512 cases per fuzz test; these are local EVM simulations with public synthetic
keys only. No RPC, operational account or deployed contract was used.

Human review is required before merging this contract change. It does not alter
an existing deployment. Formal specifications are drafts, with no proof claim.
