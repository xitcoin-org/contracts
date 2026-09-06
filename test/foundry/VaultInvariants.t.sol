// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;
import {CronosBridgeVault} from "../../contracts/cronos/bridge/CronosBridgeVault.sol";
import {AdversarialERC20} from "../../contracts/test/AdversarialERC20.sol";

interface Vm {
    function addr(uint256) external returns (address);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function chainId(uint256) external;
    function warp(uint256) external;
}
contract VaultInvariantsTest {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CronosBridgeVault vault;
    AdversarialERC20 token;
    address constant recipient = address(0x12345);
    function setUp() public {
        vm.chainId(338);
        token = new AdversarialERC20();
        address[3] memory signers = [vm.addr(1), vm.addr(2), vm.addr(3)];
        vault = new CronosBridgeVault(token, keccak256("cronos-testnet-xitcoin-testnet"), signers, address(this), 10000, 100000, false);
        token.mint(address(vault), 1000000);
    }
    function signatures(bytes32 burn, uint256 amount) internal returns(bytes[] memory sigs) {
        bytes32 domain = keccak256(abi.encode(keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(vault.EIP712_NAME())), keccak256(bytes(vault.EIP712_VERSION())), block.chainid, address(vault)));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domain, keccak256(abi.encode(vault.RELEASE_TYPEHASH(), burn, recipient, amount, uint64(1), uint256(2000000000)))));
        sigs = new bytes[](2);
        for(uint256 i; i<2; ++i) { (uint8 v,bytes32 r,bytes32 s)=vm.sign(i+1,digest); sigs[i]=abi.encodePacked(r,s,v); }
    }
    function testFuzz_releaseConservesAndCannotReplay(uint64 seed, bytes32 burn) public {
        if(burn == bytes32(0)) return;
        uint256 amount = uint256(seed)%10000+1;
        bytes[] memory sigs = signatures(burn,amount);
        vault.release(burn,recipient,amount,1,2000000000,sigs);
        require(vault.processedBurns(burn) && token.balanceOf(recipient)==amount, "exact release");
        require(token.balanceOf(address(vault))+token.balanceOf(recipient)==1000000, "conservation");
        (bool ok,) = address(vault).call(abi.encodeCall(vault.release,(burn,recipient,amount,1,2000000000,sigs)));
        require(!ok && token.balanceOf(recipient)==amount, "replay");
    }
    function testFuzz_unsignedReleaseCannotChangeAccounting(bytes32 burn,uint64 amount) public {
        uint256 beforeBalance = token.balanceOf(address(vault));
        bytes[] memory empty = new bytes[](0);
        (bool ok,) = address(vault).call(abi.encodeCall(vault.release,(burn,recipient,uint256(amount),1,2000000000,empty)));
        require(!ok && !vault.processedBurns(burn) && vault.releasedToday()==0 && token.balanceOf(address(vault))==beforeBalance,"unauthorized state change");
    }
    function testFuzz_pauseEnforced(uint64 seed) public {
        uint256 amount=uint256(seed)%10000+1;bytes32 burn=keccak256(abi.encode(seed));bytes[] memory sigs=signatures(burn,amount);
        vault.pause();
        (bool ok,) = address(vault).call(abi.encodeCall(vault.release,(burn,recipient,amount,1,2000000000,sigs)));
        require(!ok && !vault.processedBurns(burn) && vault.releasedToday()==0,"pause");
    }
    function test_adversarialTransferMustRollback() public {
        for(uint8 mode=1;mode<=4;++mode) {
            if(mode==3) continue;
            bytes32 burn=keccak256(abi.encode(mode));bytes[] memory sigs=signatures(burn,10);
            token.configure(mode,address(0),"");
            (bool ok,) = address(vault).call(abi.encodeCall(vault.release,(burn,recipient,10,1,2000000000,sigs)));
            require(!ok && !vault.processedBurns(burn) && vault.releasedToday()==0 && token.balanceOf(address(vault))==1000000 && token.balanceOf(recipient)==0,"partial completion after token failure");
        }
    }
    function test_callbackCannotReenterRelease() public {
        bytes32 burn=keccak256("callback");bytes[] memory sigs=signatures(burn,10);
        bytes32 otherBurn=keccak256("different authorized callback");
        bytes[] memory otherSigs=signatures(otherBurn,10);
        token.configure(3,address(vault),abi.encodeCall(vault.release,(otherBurn,recipient,10,1,2000000000,otherSigs)));
        vault.release(burn,recipient,10,1,2000000000,sigs);
        require(!token.callbackSucceeded() && !vault.processedBurns(otherBurn) && token.balanceOf(recipient)==10 && vault.releasedToday()==10,"reentrancy");
    }

    function testFuzz_releasePayloadAndChainBinding(uint64 seed) public {
        bytes32 burn=keccak256(abi.encode("binding",seed));
        uint256 amount=uint256(seed)%9999+1;
        bytes[] memory sigs=signatures(burn,amount);
        (bool ok,)=address(vault).call(abi.encodeCall(vault.release,(burn,recipient,amount+1,1,2000000000,sigs)));
        require(!ok,"amount mutation");
        (ok,)=address(vault).call(abi.encodeCall(vault.release,(burn,address(0x56789),amount,1,2000000000,sigs)));
        require(!ok,"recipient mutation");
        (ok,)=address(vault).call(abi.encodeCall(vault.release,(keccak256(abi.encode(burn)),recipient,amount,1,2000000000,sigs)));
        require(!ok,"burn mutation");
        (ok,)=address(vault).call(abi.encodeCall(vault.release,(burn,recipient,amount,1,2000000001,sigs)));
        require(!ok,"deadline mutation");
        (ok,)=address(vault).call(abi.encodeCall(vault.release,(burn,recipient,amount,2,2000000000,sigs)));
        require(!ok,"signer version mutation");
        vm.chainId(339);
        (ok,)=address(vault).call(abi.encodeCall(vault.release,(burn,recipient,amount,1,2000000000,sigs)));
        require(!ok,"chain mutation");
        vm.chainId(338);
        require(!vault.processedBurns(burn) && vault.releasedToday()==0 && token.balanceOf(recipient)==0,"failed binding changed state");
        // Same signatures must succeed in the intended domain; avoid a vacuous rejection test.
        vault.release(burn,recipient,amount,1,2000000000,sigs);
        require(token.balanceOf(recipient)==amount,"authorized reachability");
    }

    function testFuzz_dailyRolloverPreservesReplayAndAtomicFailure(uint64 seed) public {
        uint256 amount=uint256(seed)%10000+1;
        bytes32 first=keccak256(abi.encode("first",seed));
        bytes[] memory sigs=signatures(first,amount);
        vault.release(first,recipient,amount,1,2000000000,sigs);
        vm.warp(2 days);
        (bool ok,)=address(vault).call(abi.encodeCall(vault.release,(first,recipient,amount,1,2000000000,sigs)));
        require(!ok && vault.processedBurns(first),"rollover cleared replay");
        bytes32 second=keccak256(abi.encode("second",seed));
        bytes[] memory secondSigs=signatures(second,amount);
        uint256 dayBefore=vault.releaseDay();
        token.configure(1,address(0),"");
        (ok,)=address(vault).call(abi.encodeCall(vault.release,(second,recipient,amount,1,2000000000,secondSigs)));
        require(!ok && vault.releaseDay()==dayBefore && vault.releasedToday()==amount && !vault.processedBurns(second),"failure partially reset day");
        token.configure(0,address(0),"");
        vault.release(second,recipient,amount,1,2000000000,secondSigs);
        require(vault.releaseDay()==2 && vault.releasedToday()==amount && vault.processedBurns(first),"successful rollover accounting");
        require(token.balanceOf(recipient)==2*amount && token.balanceOf(address(vault))+token.balanceOf(recipient)==1000000,"sequence conservation");
    }
}
