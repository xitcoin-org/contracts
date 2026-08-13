# Xitcoin Upgrade Policy

## Scope

This policy applies to the canonical Xitcoin token proxy on Cronos EVM.

## Upgrade controls

The token uses the UUPS proxy pattern. Upgrades and ownership changes require approval from all three configured voter wallets.

No private key, recovery phrase, deployment credential, signer configuration, or voter address is stored in this repository.

## Required controls before an upgrade

Before any production upgrade:

1. Define the change in a reviewed source branch.
2. Compile using the documented compiler settings.
3. Validate UUPS and storage-layout compatibility.
4. Test the upgrade against a fork or equivalent test environment.
5. Obtain an independent security review proportionate to the change.
6. Deploy and verify the candidate implementation on Cronos Explorer.
7. Obtain all required voter approvals.
8. Publish a release note identifying the implementation address and audit or review reference.

## Emergency response

An emergency must be assessed before any upgrade. The current token implementation does not expose a generic pause function. Any future emergency-control mechanism requires independent design review and audit before adoption.

## Bridge separation

A bridge must use dedicated contracts and controls. It must not require a token-proxy upgrade merely to support bridging.
