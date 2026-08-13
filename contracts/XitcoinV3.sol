// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract XitcoinImplentation is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    address[3] public voters;

    /// Upgrade Voting
    mapping(address => bool) public upgradeVotes;
    uint8 public upgradeVoteCount;
    address public pendingUpgrade;
    bool private _upgradeInProgress;

    /// Owner Change Voting
    mapping(address => bool) public ownerChangeVotes;
    uint8 public ownerChangeVoteCount;
    address public pendingOwner;

    /// Proposal Cooldown
    uint256 public constant PROPOSAL_COOLDOWN_BLOCKS = 1000;
    uint256 public lastUpgradeProposalBlock;
    uint256 public lastOwnerProposalBlock;

    modifier validAddress(address addr) {
        require(addr != address(0), "Invalid address");
        _;
    }

    modifier onlyVoter() {
        require(isVoter(msg.sender), "Not a voter");
        _;
    }

    ///  events for logging
    event VotersInitilized(address[3] voters);
    event UpgradeVoteCast(address voter, address newImplementation);
    event UpgradeExecuted(address newImplementation);
    event OwnerChangeVoteCast(address voter, address newOwner);
    event OwnershipChangeExecuted(address newOwner);
    event ERC20Rescued(address token, address to, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address[3] memory votersAdmin,
        uint256 supply
    ) public initializer {
        __ERC20_init("Xitcoin", "$XTC");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        _mint(msg.sender, supply * 10 ** decimals());
        // Validate voters
        for (uint8 i = 0; i < 3; i++) {
            require(
                votersAdmin[i] != address(0),
                "Voter cannot be zero address"
            );
            for (uint8 j = i + 1; j < 3; j++) {
                require(
                    votersAdmin[i] != votersAdmin[j],
                    "Duplicate voters not allowed"
                );
            }
        }

        voters = votersAdmin;
        emit VotersInitilized(votersAdmin);
    }

    function isVoter(address account) public view returns (bool) {
        for (uint8 i = 0; i < 3; i++) {
            if (voters[i] == account) return true;
        }
        return false;
    }

    /// --- Upgrade Voting Mechanism ---
    function voteToUpgrade(
        address newImplementation
    ) public onlyVoter validAddress(newImplementation) {
        if (pendingUpgrade != newImplementation) {
            _enforceProposalCooldown(lastUpgradeProposalBlock);
            _resetUpgradeVotes();
            lastUpgradeProposalBlock = block.number;
            pendingUpgrade = newImplementation;
        }

        require(!upgradeVotes[msg.sender], "Already voted");
        upgradeVotes[msg.sender] = true;
        upgradeVoteCount++;
        emit UpgradeVoteCast(msg.sender, newImplementation);

        if (upgradeVoteCount == 3) {
            _upgradeInProgress = true;
            upgradeToAndCall(pendingUpgrade, new bytes(0));
            emit UpgradeExecuted(pendingUpgrade);
            _resetUpgradeVotes();
            _upgradeInProgress = false;
        }
    }

    function _resetUpgradeVotes() internal {
        for (uint8 i = 0; i < 3; i++) {
            upgradeVotes[voters[i]] = false;
        }
        upgradeVoteCount = 0;
        pendingUpgrade = address(0);
    }

    /// --- Owner Change Voting Mechanism ---
    function voteToChangeOwner(
        address newOwner
    ) public onlyVoter validAddress(newOwner) {
        if (pendingOwner != newOwner) {
            _enforceProposalCooldown(lastOwnerProposalBlock);
            _resetOwnerChangeVotes();
            pendingOwner = newOwner;
            lastOwnerProposalBlock = block.number;
        }

        require(!ownerChangeVotes[msg.sender], "Already voted to change owner");
        ownerChangeVotes[msg.sender] = true;
        ownerChangeVoteCount++;
        emit OwnerChangeVoteCast(msg.sender, newOwner);

        if (ownerChangeVoteCount == 3) {
            _transferOwnership(pendingOwner);
            emit OwnershipChangeExecuted(pendingOwner);
            _resetOwnerChangeVotes();
        }
    }

    function _resetOwnerChangeVotes() internal {
        for (uint8 i = 0; i < 3; i++) {
            ownerChangeVotes[voters[i]] = false;
        }
        ownerChangeVoteCount = 0;
        pendingOwner = address(0);
    }

    function _enforceProposalCooldown(uint256 lastBlock) internal view {
        require(
            block.number > lastBlock + PROPOSAL_COOLDOWN_BLOCKS,
            "Proposal cooldown: wait before changing"
        );
    }

    /// Burn function (Owner-only)
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    /// Renounce ownership is disabled
    function renounceOwnership() public override onlyOwner {
        revert("Renouncing ownership is disabled");
    }

    /// UUPS Authorization
    function _authorizeUpgrade(
        address newImplementation
    ) internal view override {
        require(
            _upgradeInProgress && newImplementation == pendingUpgrade,
            "Unauthorized upgrade"
        );
    }

    /// ERC20 rescue
    function rescueERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner validAddress(token) validAddress(to) {
        IERC20(token).safeTransfer(to, amount);
        emit ERC20Rescued(token, to, amount);
    }
}
