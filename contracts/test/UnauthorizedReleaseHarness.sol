// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import {CronosBridgeVault} from "../cronos/bridge/CronosBridgeVault.sol";
import {MockERC20} from "./MockERC20.sol";

// Echidna negative-authorization campaign. No signing capability or RPC.
contract UnauthorizedReleaseHarness {
    CronosBridgeVault public vault;
    MockERC20 public token;
    bool public unauthorizedSuccess;
    constructor() {
        token = new MockERC20("Synthetic", "TEST");
        vault = new CronosBridgeVault(token, keccak256("synthetic-route"),
            [address(0x1111),address(0x2222),address(0x3333)],address(0x4444),10000,100000,false);
        token.mint(address(vault),1000000);
    }
    function attempt(bytes32 burn,address recipient,uint64 amount,bytes calldata signature) external {
        bytes[] memory signatures = new bytes[](2);
        signatures[0]=signature;signatures[1]=signature;
        (bool ok,) = address(vault).call(abi.encodeCall(vault.release,(burn,recipient,uint256(amount),1,2000000000,signatures)));
        if(ok) unauthorizedSuccess=true;
    }
    function attemptPause() external {
        (bool ok,)=address(vault).call(abi.encodeCall(vault.pause,()));
        if(ok) unauthorizedSuccess=true;
    }
    function echidna_no_unauthorized_success() external view returns(bool) { return !unauthorizedSuccess; }
    function echidna_conserved_custody() external view returns(bool) { return token.balanceOf(address(vault))==1000000 && vault.releasedToday()==0; }
    function echidna_guardian_access() external view returns(bool) { return !vault.paused(); }
}
