# Candidate vault and escrow obligations

These are specification candidates, not executable CVL or a completed proof.
Certora, Forge, Echidna and Mythril were not run to establish them. Any harness
must bind the exact compiler input, canonical token model and immutable
constructor parameters, and separate honest-token assumptions from adversarial
ERC-20 behavior.

| Obligation | Source enforcement to review | Required adversarial case |
|---|---|---|
| Authorized release only | EIP-712 digest; `_verifyQuorum`; current signer set | One signer, outsider, duplicates, altered signatures and signer rotation |
| At-most-once burn release | `processedBurns` checked before release, set before transfer | Repeated calls, callback reentrancy, failure followed by retry |
| Paused vault cannot deposit/release | `whenNotPaused` | Every deposit/release entry while paused, including callbacks |
| Payload and domain binding | Burn ID, recipient, amount, version, deadline; chain and vault EIP-712 domain | Mutate each field, chain or vault independently; wrong route/source mapping in signer service |
| Monotonic governance | Current nonce and signer-set version, increment on success | Replay controls across actions and rotations; failed control must not consume nonce |
| Atomic failed release | Reverting transfer rolls back replay flag and daily accounting | Reverting/false-returning ERC-20; callback; insufficient balance |
| Conservation | Exact deposit delta; bounded release and available balance | Direct donations, fee/rebase tokens, self-recipient and upgradeable-token behavior |
| Escrow terminal states | Funded precedes Activated or Cancelled; fixed recipients | Cross-terminal calls, double decisions, late transfers and failed transfer rollback |
| Privileged authority explicit | Quorum can resume, rotate, change limits and guardian | Show that quorum can raise limits; do not model a limit as immutable loss protection |

The vault does not itself prove a native-chain burn or its finality. The signer
service and destination adapter must bind route, source-chain identity and
canonical burn evidence. Immutable vault/route mapping is a deployment assumption,
not a field independently signed in the `Release` struct.

The guardian can pause, but the same signer quorum can replace the guardian,
raise limits and resume. A model must not assume the guardian can permanently
veto a compromised quorum. Assess delayed governance or distinct control roles
as a separate design decision, not a silent contract change.

For conservation, distinguish token-reported transfer success from recipient
balance changes. `SafeERC20` alone cannot establish honest accounting for an
arbitrary or subsequently upgraded asset. Prove the invariant under an explicit
token model and test failures when that model is relaxed.
