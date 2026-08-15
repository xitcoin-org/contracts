// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";



contract Migration is ReentrancyGuard {
    using SafeERC20 for IERC20Metadata;
    IERC20Metadata public immutable fromToken;
    IERC20Metadata public immutable toToken;

    uint8 public immutable fromTokenDecimals;
    uint8 public immutable toTokenDecimals;

    event SwapExecuted(address indexed from, address indexed to, uint256 amount);

    constructor(address _fromToken, address _toToken) {
        require(_fromToken != address(0), "From token address cannot be zero");
        require(_toToken != address(0), "To token address cannot be zero");
        fromToken = IERC20Metadata(_fromToken);
        toToken = IERC20Metadata(_toToken);

        fromTokenDecimals = fromToken.decimals();
        toTokenDecimals = toToken.decimals();
    }

    function swapTokens(
        uint256 amount
    ) external nonReentrant{
        require(amount > 0, "Amount must be greater than zero");
        address deadAddress = 0x000000000000000000000000000000000000dEaD;

        // Transfer tokens from the sender to this contract
        // fromToken.safeTransferFrom(msg.sender, address(this), amount);

        require(fromToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // fromToken.safeTransfer(deadAddress, amount);
        require(fromToken.transfer(deadAddress, amount), "Transfer to dead address failed");
        //normalize the amount to the decimals of the toToken
        uint256 normalizedAmount = normalizeAmount(amount, fromTokenDecimals, toTokenDecimals);
        
        // Transfer tokens from this contract to the sender
        // toToken.safeTransfer(msg.sender, normalizedAmount);
        require(toToken.transfer(msg.sender, normalizedAmount), "Transfer to sender failed");
        
        emit SwapExecuted(address(fromToken), address(toToken), amount);
    }


    function normalizeAmount(
        uint256 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) internal pure returns (uint256) {
        if (fromDecimals > toDecimals) {
            return amount / (10 ** (fromDecimals - toDecimals));
        } else if (fromDecimals < toDecimals) {
            return amount * (10 ** (toDecimals - fromDecimals));
        } else {
            return amount;
        }
    }

}