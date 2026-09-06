# Draft formal obligations

`CronosBridgeVault.spec` is an INO internal draft, not a completed formal proof.
The Certora CLI and authorized prover access were absent during this review.
No credentials were requested, read or sent. No prover was executed and the
specification has not been typechecked. An authorized reviewer must configure
an exact compiler/tool revision, link the token model, inspect external-call
approximations and discharge vacuity/reachability checks before running it.

Rules cover pause enforcement, replay rejection, rollback of burn/daily state,
and monotonic processed-burn state across external functions. `lastReverted`
is captured immediately after the tested call, before any getter can overwrite
it. No rule assumes successful authorization or summarizes token transfers as
successful. Successful-release reachability, quorum cryptography, exact token
balance conservation, callback behavior, escrow lifecycle, guardian limits and
route/domain separation still need additional specifications and model review.

Syntax sources: [CVL methods](https://docs.certora.com/en/latest/docs/cvl/methods.html)
and [call/revert semantics](https://docs.certora.com/en/latest/docs/cvl/expr.html).
The Foundry regressions are executable testing evidence; they do not prove these
formal obligations or production readiness.
