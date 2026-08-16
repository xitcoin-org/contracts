// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CronosBridgeVault
/// @notice Locks canonical Cronos XTC and releases it after a quorum-signed
///         native Xitcoin burn attestation.
/// @dev This contract cannot mint or burn XTC and has no owner withdrawal.
contract CronosBridgeVault is EIP712, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    string public constant EIP712_NAME = "Xitcoin Cronos Bridge Vault";
    string public constant EIP712_VERSION = "1";
    uint256 public constant SIGNATURE_THRESHOLD = 2;
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    bytes32 public constant RELEASE_TYPEHASH = keccak256(
        "Release(bytes32 sourceBurnId,address recipient,uint256 amount,uint64 signerSetVersion,uint256 deadline)"
    );
    bytes32 public constant CONTROL_TYPEHASH = keccak256(
        "Control(bytes32 action,bytes32 payloadHash,uint256 nonce,uint64 signerSetVersion,uint256 deadline)"
    );

    bytes32 public constant ACTION_RESUME = keccak256("RESUME");
    bytes32 public constant ACTION_ROTATE_SIGNERS =
        keccak256("ROTATE_SIGNERS");
    bytes32 public constant ACTION_UPDATE_LIMITS =
        keccak256("UPDATE_LIMITS");
    bytes32 public constant ACTION_CHANGE_GUARDIAN =
        keccak256("CHANGE_GUARDIAN");
    bytes32 public constant ACTION_RESCUE_FOREIGN_TOKEN =
        keccak256("RESCUE_FOREIGN_TOKEN");

    IERC20 public immutable asset;
    bytes32 public immutable routeId;

    address[3] private _signers;
    mapping(address signer => bool enabled) public isSigner;
    uint64 public signerSetVersion;

    address public guardian;
    uint256 public governanceNonce;
    uint256 public depositNonce;

    uint256 public maxReleaseAmount;
    uint256 public dailyReleaseLimit;
    uint256 public releaseDay;
    uint256 public releasedToday;

    mapping(bytes32 sourceBurnId => bool processed) public processedBurns;

    error InvalidAddress();
    error InvalidAmount();
    error InvalidRoute();
    error InvalidSignerSet();
    error InvalidSignerSetVersion();
    error InvalidNonce();
    error SignatureExpired();
    error InsufficientSignatures();
    error DuplicateSignature();
    error UnauthorizedSigner();
    error UnauthorizedGuardian();
    error BurnAlreadyProcessed();
    error ReleaseLimitExceeded();
    error DailyLimitExceeded();
    error InsufficientLiquidity();
    error UnsupportedTokenBehavior();
    error CanonicalAssetRescueForbidden();

    event Deposited(
        bytes32 indexed depositId,
        bytes32 indexed routeId,
        address indexed depositor,
        address recipient,
        uint256 amount,
        uint256 nonce
    );
    event Released(
        bytes32 indexed sourceBurnId,
        address indexed recipient,
        uint256 amount,
        uint64 signerSetVersion
    );
    event VaultPaused(address indexed guardian);
    event VaultResumed(uint256 indexed governanceNonce);
    event SignersRotated(
        uint64 indexed signerSetVersion,
        address signerOne,
        address signerTwo,
        address signerThree,
        uint256 governanceNonce
    );
    event LimitsUpdated(
        uint256 maxReleaseAmount,
        uint256 dailyReleaseLimit,
        uint256 governanceNonce
    );
    event GuardianChanged(
        address indexed previousGuardian,
        address indexed newGuardian,
        uint256 governanceNonce
    );
    event ForeignTokenRescued(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 governanceNonce
    );

    constructor(
        IERC20 canonicalAsset,
        bytes32 canonicalRouteId,
        address[3] memory initialSigners,
        address initialGuardian,
        uint256 initialMaxReleaseAmount,
        uint256 initialDailyReleaseLimit
    ) EIP712(EIP712_NAME, EIP712_VERSION) {
        if (address(canonicalAsset) == address(0)) revert InvalidAddress();
        if (canonicalRouteId == bytes32(0)) revert InvalidRoute();
        if (!_isValidRecipient(initialGuardian)) revert InvalidAddress();
        _validateLimits(initialMaxReleaseAmount, initialDailyReleaseLimit);

        asset = canonicalAsset;
        routeId = canonicalRouteId;
        guardian = initialGuardian;
        maxReleaseAmount = initialMaxReleaseAmount;
        dailyReleaseLimit = initialDailyReleaseLimit;

        _setSigners(initialSigners);
        signerSetVersion = 1;
    }

    /// @notice Returns the current bridge signer set.
    function signers() external view returns (address[3] memory) {
        return _signers;
    }

    /// @notice Returns the canonical XTC currently available for releases.
    function availableLiquidity() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    /// @notice Locks canonical Cronos XTC for a recipient on Xitcoin.
    function deposit(
        uint256 amount,
        address recipient
    ) external whenNotPaused nonReentrant returns (bytes32 depositId) {
        if (amount == 0) revert InvalidAmount();
        if (!_isValidRecipient(recipient)) revert InvalidAddress();

        uint256 balanceBefore = asset.balanceOf(address(this));
        asset.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = asset.balanceOf(address(this));

        if (balanceAfter - balanceBefore != amount) {
            revert UnsupportedTokenBehavior();
        }

        uint256 nonce = ++depositNonce;
        depositId = keccak256(
            abi.encode(
                block.chainid,
                address(this),
                routeId,
                msg.sender,
                recipient,
                amount,
                nonce
            )
        );

        emit Deposited(
            depositId,
            routeId,
            msg.sender,
            recipient,
            amount,
            nonce
        );
    }

    /// @notice Releases locked Cronos XTC after a quorum-signed Xitcoin burn.
    function release(
        bytes32 sourceBurnId,
        address recipient,
        uint256 amount,
        uint64 releaseSignerSetVersion,
        uint256 deadline,
        bytes[] calldata signatures
    ) external whenNotPaused nonReentrant {
        if (sourceBurnId == bytes32(0)) revert InvalidRoute();
        if (!_isValidRecipient(recipient)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        if (processedBurns[sourceBurnId]) revert BurnAlreadyProcessed();
        if (releaseSignerSetVersion != signerSetVersion) {
            revert InvalidSignerSetVersion();
        }
        if (block.timestamp > deadline) revert SignatureExpired();
        if (amount > maxReleaseAmount) revert ReleaseLimitExceeded();

        _applyDailyLimit(amount);

        if (asset.balanceOf(address(this)) < amount) {
            revert InsufficientLiquidity();
        }

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    RELEASE_TYPEHASH,
                    sourceBurnId,
                    recipient,
                    amount,
                    releaseSignerSetVersion,
                    deadline
                )
            )
        );
        _verifyQuorum(digest, signatures);

        processedBurns[sourceBurnId] = true;
        asset.safeTransfer(recipient, amount);

        emit Released(
            sourceBurnId,
            recipient,
            amount,
            releaseSignerSetVersion
        );
    }

    /// @notice Allows the guardian to stop deposits and releases immediately.
    function pause() external {
        if (msg.sender != guardian) revert UnauthorizedGuardian();
        _pause();
        emit VaultPaused(msg.sender);
    }

    /// @notice Resumes the vault after current bridge signer approval.
    function resume(
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external whenPaused {
        uint256 consumedNonce = _authorizeControl(
            ACTION_RESUME,
            bytes32(0),
            nonce,
            deadline,
            signatures
        );
        _unpause();
        emit VaultResumed(consumedNonce);
    }

    /// @notice Rotates all three bridge signers after current signer approval.
    function rotateSigners(
        address[3] calldata newSigners,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external {
        _validateSigners(newSigners);
        uint256 consumedNonce = _authorizeControl(
            ACTION_ROTATE_SIGNERS,
            keccak256(abi.encode(newSigners)),
            nonce,
            deadline,
            signatures
        );

        _setSigners(newSigners);
        ++signerSetVersion;

        emit SignersRotated(
            signerSetVersion,
            newSigners[0],
            newSigners[1],
            newSigners[2],
            consumedNonce
        );
    }

    /// @notice Updates per-release and daily release limits by signer quorum.
    function updateLimits(
        uint256 newMaxReleaseAmount,
        uint256 newDailyReleaseLimit,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external {
        _validateLimits(newMaxReleaseAmount, newDailyReleaseLimit);
        uint256 consumedNonce = _authorizeControl(
            ACTION_UPDATE_LIMITS,
            keccak256(
                abi.encode(newMaxReleaseAmount, newDailyReleaseLimit)
            ),
            nonce,
            deadline,
            signatures
        );

        maxReleaseAmount = newMaxReleaseAmount;
        dailyReleaseLimit = newDailyReleaseLimit;

        emit LimitsUpdated(
            newMaxReleaseAmount,
            newDailyReleaseLimit,
            consumedNonce
        );
    }

    /// @notice Changes the emergency guardian by signer quorum.
    function changeGuardian(
        address newGuardian,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external {
        if (!_isValidRecipient(newGuardian)) revert InvalidAddress();
        uint256 consumedNonce = _authorizeControl(
            ACTION_CHANGE_GUARDIAN,
            keccak256(abi.encode(newGuardian)),
            nonce,
            deadline,
            signatures
        );

        address previousGuardian = guardian;
        guardian = newGuardian;
        emit GuardianChanged(previousGuardian, newGuardian, consumedNonce);
    }

    /// @notice Recovers an unrelated ERC-20 sent to the vault by mistake.
    /// @dev Canonical XTC can never be transferred through this function.
    function rescueForeignToken(
        IERC20 token,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) external nonReentrant {
        if (address(token) == address(asset)) {
            revert CanonicalAssetRescueForbidden();
        }
        if (address(token) == address(0) || !_isValidRecipient(recipient)) {
            revert InvalidAddress();
        }
        if (amount == 0) revert InvalidAmount();

        uint256 consumedNonce = _authorizeControl(
            ACTION_RESCUE_FOREIGN_TOKEN,
            keccak256(abi.encode(address(token), recipient, amount)),
            nonce,
            deadline,
            signatures
        );

        token.safeTransfer(recipient, amount);
        emit ForeignTokenRescued(
            address(token),
            recipient,
            amount,
            consumedNonce
        );
    }

    function _authorizeControl(
        bytes32 action,
        bytes32 payloadHash,
        uint256 nonce,
        uint256 deadline,
        bytes[] calldata signatures
    ) internal returns (uint256 consumedNonce) {
        if (nonce != governanceNonce) revert InvalidNonce();
        if (block.timestamp > deadline) revert SignatureExpired();

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    CONTROL_TYPEHASH,
                    action,
                    payloadHash,
                    nonce,
                    signerSetVersion,
                    deadline
                )
            )
        );
        _verifyQuorum(digest, signatures);

        consumedNonce = nonce;
        governanceNonce = nonce + 1;
    }

    function _verifyQuorum(
        bytes32 digest,
        bytes[] calldata signatures
    ) internal view {
        if (signatures.length < SIGNATURE_THRESHOLD) {
            revert InsufficientSignatures();
        }

        address[] memory recovered = new address[](signatures.length);
        uint256 approvals;

        for (uint256 i = 0; i < signatures.length; ++i) {
            address signer = ECDSA.recover(digest, signatures[i]);
            if (!isSigner[signer]) revert UnauthorizedSigner();

            for (uint256 j = 0; j < i; ++j) {
                if (recovered[j] == signer) revert DuplicateSignature();
            }

            recovered[i] = signer;
            ++approvals;
        }

        if (approvals < SIGNATURE_THRESHOLD) {
            revert InsufficientSignatures();
        }
    }

    function _applyDailyLimit(uint256 amount) internal {
        uint256 today = block.timestamp / 1 days;
        if (today != releaseDay) {
            releaseDay = today;
            releasedToday = 0;
        }

        uint256 updatedReleasedToday = releasedToday + amount;
        if (updatedReleasedToday > dailyReleaseLimit) {
            revert DailyLimitExceeded();
        }
        releasedToday = updatedReleasedToday;
    }

    function _setSigners(address[3] memory newSigners) internal {
        _validateSigners(newSigners);

        for (uint256 i = 0; i < _signers.length; ++i) {
            if (_signers[i] != address(0)) {
                isSigner[_signers[i]] = false;
            }
        }

        _signers = newSigners;
        for (uint256 i = 0; i < newSigners.length; ++i) {
            isSigner[newSigners[i]] = true;
        }
    }

    function _validateSigners(address[3] memory candidateSigners) internal pure {
        for (uint256 i = 0; i < candidateSigners.length; ++i) {
            if (!_isValidRecipient(candidateSigners[i])) {
                revert InvalidSignerSet();
            }
            for (uint256 j = i + 1; j < candidateSigners.length; ++j) {
                if (candidateSigners[i] == candidateSigners[j]) {
                    revert InvalidSignerSet();
                }
            }
        }
    }

    function _validateLimits(
        uint256 candidateMaxReleaseAmount,
        uint256 candidateDailyReleaseLimit
    ) internal pure {
        if (
            candidateMaxReleaseAmount == 0 ||
            candidateDailyReleaseLimit == 0 ||
            candidateMaxReleaseAmount > candidateDailyReleaseLimit
        ) {
            revert InvalidAmount();
        }
    }

    function _isValidRecipient(address account) internal pure returns (bool) {
        return account != address(0) && account != DEAD_ADDRESS;
    }
}
