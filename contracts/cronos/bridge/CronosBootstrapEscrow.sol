// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CronosBootstrapEscrow
/// @notice Holds the one-time Cronos XTC mainnet bootstrap reserve until a
///         2-of-3 quorum either activates the permanent bridge vault or
///         cancels the unopened network and refunds the fixed funding account.
/// @dev The Xitcoin network MUST remain private until `activate` succeeds.
///      There is no arbitrary recipient and each terminal outcome excludes the other.
contract CronosBootstrapEscrow is EIP712, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public constant EIP712_NAME = "Xitcoin Cronos Bootstrap Escrow";
    string public constant EIP712_VERSION = "1";
    uint256 public constant SIGNATURE_THRESHOLD = 2;
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    bytes32 public constant DECISION_TYPEHASH = keccak256(
        "Decision(bytes32 action,bytes32 genesisHash,uint256 expectedAmount,uint256 nonce,uint256 deadline)"
    );
    bytes32 public constant ACTION_ACTIVATE = keccak256("ACTIVATE");
    bytes32 public constant ACTION_CANCEL = keccak256("CANCEL");

    enum State {
        AwaitingFunding,
        Funded,
        Activated,
        Cancelled
    }

    IERC20 public immutable asset;
    address public immutable permanentVault;
    address public immutable refundRecipient;
    address public immutable fundingAccount;
    bytes32 public immutable genesisHash;
    uint256 public immutable expectedAmount;

    address[3] private _signers;
    mapping(address signer => bool enabled) public isSigner;
    uint256 public decisionNonce;
    State public state;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidGenesisHash();
    error InvalidSignerSet();
    error InvalidState();
    error UnauthorizedFunder();
    error InvalidNonce();
    error SignatureExpired();
    error InsufficientSignatures();
    error DuplicateSignature();
    error UnauthorizedSigner();
    error UnsupportedTokenBehavior();
    error InsufficientFunding();

    event BootstrapFunded(address indexed funder, uint256 amount);
    event BootstrapActivated(
        address indexed permanentVault,
        uint256 transferredAmount,
        bytes32 indexed genesisHash
    );
    event BootstrapCancelled(
        address indexed refundRecipient,
        uint256 refundedAmount,
        bytes32 indexed genesisHash
    );
    event TerminalBalanceForwarded(
        address indexed fixedRecipient,
        uint256 amount,
        State indexed terminalState
    );

    constructor(
        IERC20 canonicalAsset,
        address finalVault,
        address fixedRefundRecipient,
        address fixedFundingAccount,
        bytes32 canonicalGenesisHash,
        uint256 bootstrapAmount,
        address[3] memory decisionSigners
    ) EIP712(EIP712_NAME, EIP712_VERSION) {
        if (
            !_isValidAddress(address(canonicalAsset)) ||
            !_isValidAddress(finalVault) ||
            !_isValidAddress(fixedRefundRecipient) ||
            !_isValidAddress(fixedFundingAccount) ||
            finalVault == fixedRefundRecipient
        ) revert InvalidAddress();
        if (canonicalGenesisHash == bytes32(0)) revert InvalidGenesisHash();
        if (bootstrapAmount == 0) revert InvalidAmount();

        _validateSigners(decisionSigners);

        asset = canonicalAsset;
        permanentVault = finalVault;
        refundRecipient = fixedRefundRecipient;
        fundingAccount = fixedFundingAccount;
        genesisHash = canonicalGenesisHash;
        expectedAmount = bootstrapAmount;
        _signers = decisionSigners;
        for (uint256 i = 0; i < decisionSigners.length; ++i) {
            isSigner[decisionSigners[i]] = true;
        }
    }

    function signers() external view returns (address[3] memory) {
        return _signers;
    }

    /// @notice Pulls the exact bootstrap reserve from the fixed funding account.
    function fund() external nonReentrant {
        if (msg.sender != fundingAccount) revert UnauthorizedFunder();
        if (state != State.AwaitingFunding) revert InvalidState();

        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.safeTransferFrom(msg.sender, address(this), expectedAmount);
        uint256 balanceAfter = asset.balanceOf(address(this));
        if (balanceAfter - balanceBefore != expectedAmount) {
            revert UnsupportedTokenBehavior();
        }

        state = State.Funded;
        emit BootstrapFunded(msg.sender, expectedAmount);
    }

    /// @notice Irreversibly moves all canonical XTC held here to the permanent vault.
    function activate(
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external nonReentrant {
        _authorize(ACTION_ACTIVATE, nonce, deadline, signatures);
        state = State.Activated;

        uint256 amount = asset.balanceOf(address(this));
        if (amount < expectedAmount) revert InsufficientFunding();
        asset.safeTransfer(permanentVault, amount);

        emit BootstrapActivated(permanentVault, amount, genesisHash);
    }

    /// @notice Refunds all canonical XTC if the still-private launch is abandoned.
    function cancel(
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external nonReentrant {
        _authorize(ACTION_CANCEL, nonce, deadline, signatures);
        state = State.Cancelled;

        uint256 amount = asset.balanceOf(address(this));
        if (amount < expectedAmount) revert InsufficientFunding();
        asset.safeTransfer(refundRecipient, amount);

        emit BootstrapCancelled(refundRecipient, amount, genesisHash);
    }

    /// @notice Forwards canonical XTC sent directly after the terminal decision.
    /// @dev Anyone may trigger this, but the recipient is fixed by the terminal
    ///      state: the permanent vault after activation, or the refund recipient
    ///      after cancellation. No caller can redirect the funds.
    function forwardTerminalBalance() external nonReentrant {
        State terminalState = state;
        if (
            terminalState != State.Activated &&
            terminalState != State.Cancelled
        ) revert InvalidState();

        uint256 amount = asset.balanceOf(address(this));
        if (amount < 1) revert InvalidAmount();

        address fixedRecipient = terminalState == State.Activated
            ? permanentVault
            : refundRecipient;
        asset.safeTransfer(fixedRecipient, amount);
        emit TerminalBalanceForwarded(
            fixedRecipient,
            amount,
            terminalState
        );
    }

    function _authorize(
        bytes32 action,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) internal {
        if (state != State.Funded) revert InvalidState();
        if (nonce != decisionNonce) revert InvalidNonce();
        if (block.timestamp > deadline) revert SignatureExpired();

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    DECISION_TYPEHASH,
                    action,
                    genesisHash,
                    expectedAmount,
                    nonce,
                    deadline
                )
            )
        );
        _verifyQuorum(digest, signatures);
        decisionNonce = nonce + 1;
    }

    function _verifyQuorum(
        bytes32 digest,
        bytes[] calldata signatures
    ) internal view {
        if (signatures.length < SIGNATURE_THRESHOLD) {
            revert InsufficientSignatures();
        }

        address[] memory recovered = new address[](signatures.length);
        for (uint256 i = 0; i < signatures.length; ++i) {
            address signer = ECDSA.recover(digest, signatures[i]);
            if (!isSigner[signer]) revert UnauthorizedSigner();
            for (uint256 j = 0; j < i; ++j) {
                if (recovered[j] == signer) revert DuplicateSignature();
            }
            recovered[i] = signer;
        }
    }

    function _validateSigners(address[3] memory candidateSigners) internal pure {
        for (uint256 i = 0; i < candidateSigners.length; ++i) {
            if (!_isValidAddress(candidateSigners[i])) {
                revert InvalidSignerSet();
            }
            for (uint256 j = i + 1; j < candidateSigners.length; ++j) {
                if (candidateSigners[i] == candidateSigners[j]) {
                    revert InvalidSignerSet();
                }
            }
        }
    }

    function _isValidAddress(address account) internal pure returns (bool) {
        return account != address(0) && account != DEAD_ADDRESS;
    }
}
