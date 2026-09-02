// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fixed-supply test asset for the isolated Cronos testnet bridge.
/// @dev This contract is not the canonical XTC token and must never be deployed
///      or registered on Cronos mainnet.
contract XitcoinTestnetToken is ERC20 {
    error InvalidRecipient();
    error InvalidSupply();

    constructor(address recipient, uint256 supply)
        ERC20("Xitcoin Testnet Token", "tXTC")
    {
        if (recipient == address(0)) revert InvalidRecipient();
        if (supply == 0) revert InvalidSupply();
        _mint(recipient, supply);
    }
}
