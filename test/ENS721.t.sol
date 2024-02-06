// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryV2} from "../contracts/RegistryV2.sol";

contract ENS721Test is Test {

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");    

    RegistryV2 public ensRegistry;

    // the main account that will be used to test
    address public account = 0x0000000000000000000000000000000000001101;

    function setUp() public {

        vm.warp(1641070800); 
        vm.startPrank(account);

        ensRegistry = new RegistryV2();

        // add the role of CONTROLLER_ROLE to the account
        ensRegistry.grantRole(CONTROLLER_ROLE, account);
    }

    // test the contract is initialized correctly
    function testInit() public {
        assertEq(ensRegistry.name(), "ENS_RegistryV2");
        assertEq(ensRegistry.symbol(), "ENSV2");
    }

    // make sure we can mint a token
    function testMint() public {
        ensRegistry.mint(address(this), 1);
        assertEq(ensRegistry.ownerOf(1), address(this));
    }

}
