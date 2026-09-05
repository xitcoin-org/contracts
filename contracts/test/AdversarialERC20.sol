// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Local tests only. Simulates a changed asset implementation without any deployment script.
contract AdversarialERC20 is ERC20 {
    uint8 public behavior;
    address public callbackTarget;
    bytes public callbackData;
    bool public callbackSucceeded;
    constructor() ERC20("Synthetic adversarial token", "TEST") {}
    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function configure(uint8 mode, address target, bytes calldata data) external {
        behavior = mode; callbackTarget = target; callbackData = data;
    }
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (behavior == 1) return true; // dishonest success with no movement
        if (behavior == 2) { _transfer(msg.sender, to, amount - 1); _burn(msg.sender, 1); return true; }
        if (behavior == 3) { (callbackSucceeded,) = callbackTarget.call(callbackData); }
        if (behavior == 4) return false;
        return super.transfer(to, amount);
    }
}
