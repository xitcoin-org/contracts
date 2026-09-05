# INO Security Audit Platform

This is an internal engineering review structure for reproducible security
evidence. It is not an independent external audit or a formal-verification
claim. Passing tests or scanners does not establish production readiness.

## Review record

For each review, record the repository and full commit, dirty-tree state,
reviewed paths, assumptions, commands, tool versions, exit codes, artifact
hashes and unexecuted checks. Keep private inputs and raw secret-scan reports
outside public artifacts. Never collect environment dumps or signing material.

```sh
python3 scripts/audit-manifest.py --output /tmp/contracts-audit-manifest.json \
  --evidence /path/to/sanitized-compile.log \
  --evidence /path/to/sanitized-slither.json
```

The script hashes contract, test, deployment-tool source and lockfile inputs;
it does not run those tools. It refuses to overwrite existing evidence. Keep
actual tool versions and command exit codes beside the manifest; an evidence
file hash is not proof that its claimed command succeeded.

## Review layers

| Layer | Current source or proposed use | Required evidence |
|---|---|---|
| Compilation | Hardhat 3.14.0; Solidity 0.8.4 and 0.8.30, as configured | Standard JSON input/output, compiler identity, settings, bytecode hashes |
| Dependency audit | Locked npm tree, production and complete toolchain separately | Advisory IDs, versions, dependency paths and exposure assessment |
| Slither | Existing CI pins 0.11.6 and the action commit | JSON results, filters, detector count and manual dispositions |
| Secret scanning | Gitleaks 8.30.0; redacted full-history and current-tree scans | Commit range, configuration hash, redacted locations and triage |
| CodeQL | Appropriate for repository JavaScript and Actions; not a Solidity proof | Database/query versions, language scope and SARIF |
| Foundry / Forge | Proposed isolated invariant and coverage harness | Pinned release, seed, run/depth limits, coverage and replayable failures |
| Echidna | Proposed stateful vault/escrow sequences | Pinned image digest, corpus, seed, configuration and assertions |
| Mythril | Proposed targeted bytecode analysis | Compiler binding, pinned version, timeout and unsupported-operation report |
| Certora | [Candidate obligations](INVARIANTS.md), not an executed proof | Reviewed CVL, models, exact prover version and successful run artifacts |

Run only tasks authorized for the review. Repository-only work must not start
services, resolve operational credentials or contact chain endpoints. A local
contract simulation must be identified as a simulation; it is never testnet
transaction evidence. No chain execution is performed by this structure.

## Finding lifecycle

Every finding needs an ID, repository/revision, file and location, severity,
evidence, exploit assumptions, remediation, validation status and a classification
of confirmed, suspected or informational. Track remediation PR and regression
evidence separately from the original observation.

Critical: plausible catastrophic loss or systemic compromise. High: major
unauthorized asset/state change. Medium: bounded security impact or material
availability failure. Low: limited hardening issue. Informational: expected
behavior, process limitation or unproven scanner observation. Severity is a
review conclusion; a scanner's label is recorded separately.

A false positive needs a source-level explanation and reviewer, not a blanket
exclusion. Suppress only an exact rule/location after review; re-evaluate when
source or tool version changes. Never downgrade an unavailable check to passed.

## CI proposal requiring review

Keep the existing compilation, test, dependency and Slither checks. Propose
additional jobs separately, with read-only contents permission, immutable action
commits/container digests, disabled checkout credential persistence, timeouts,
concurrency limits and sanitized artifact uploads. Never execute untrusted PR
code with deployment secrets or write-capable tokens. Resolve and review exact
pins before enabling a new scanner; no floating `latest` tool installation.

Add redacted Gitleaks history scanning and JavaScript/Actions CodeQL coverage
where supported. Add Forge/Echidna invariant jobs only after harness review;
record deterministic seeds plus bounded exploratory campaigns. Certora requires
separate execution authorization and successful prover output before any formal
verification statement. This proposal changes no workflows or branch rules.
