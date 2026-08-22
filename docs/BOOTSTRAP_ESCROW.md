# Cronos bootstrap escrow

`CronosBootstrapEscrow` is a one-time safety boundary for the initial native
XTC reserve. It does not replace `CronosBridgeVault` and it does not add an
administrator withdrawal to that permanent vault.

## Required sequence

1. Deploy the permanent bridge vault and the bootstrap escrow with reviewed,
   immutable addresses, the canonical genesis SHA-256, the exact bootstrap
   amount and three independent decision signers.
2. The fixed funding account approves and funds the escrow once.
3. Build and start the Xitcoin network privately. Public RPC, public P2P entry,
   deposits and user transfers remain closed.
4. If the private launch fails, two of three signers authorize `cancel`. Every
   canonical `$XTC` unit held by the escrow returns to the immutable refund
   recipient and that escrow can never be activated.
5. If the private launch passes its acceptance checks, two of three signers
   authorize `activate`. Every canonical `$XTC` unit held by the escrow moves
   to the immutable permanent vault and that escrow can never be cancelled.
6. Only after activation is confirmed on Cronos may the Xitcoin mainnet become
   public.

## Safety properties

- Activation and cancellation are mutually exclusive terminal states.
- Both decisions require two distinct authorized EIP-712 signatures.
- Signatures are bound to the Cronos chain, escrow address, decision, genesis
  hash, expected amount, nonce and deadline.
- Funding, refund and permanent-vault addresses are immutable.
- There is no arbitrary canonical-token recipient and no owner withdrawal.
- Directly transferred canonical dust follows the full reserve to the same
  fixed terminal recipient; it cannot be redirected.

## Deployment rule

Do not deploy or fund from placeholders. Record and independently verify the
canonical `$XTC` proxy, implementation, escrow, permanent vault, refund
recipient, funding account, signer addresses, genesis hash, expected amount,
transaction hashes and bytecode verification before moving real value.
