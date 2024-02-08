// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ENS721} from "../contracts/ENS721.sol";
import {RootController} from "../contracts/RootController.sol";
import {IENS721} from "../contracts/IENS721.sol";
import {FuseController} from "../contracts/FuseController.sol";
import {BytesUtils} from "../contracts/BytesUtils.sol";

contract ENS721Test is Test {

    using BytesUtils for bytes;

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");    

    ENS721 public ensRegistry;
    RootController public rootController;
    FuseController public fuseController;

    // the main account that will be used to test
    address public account = 0x0000000000000000000000000000000000001101;
    address public resolver = 0x0000000000000000000000000000000000004404; 

    bytes32 private constant ETH_LABELHASH =
        0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;

    function setUp() public {
        vm.warp(1641070800); 
        vm.startPrank(account);

        rootController = new RootController(address(ensRegistry));

        ensRegistry = new ENS721("ENS_RegistryV2", "ENSV2", address(rootController));

        // add the registry address to the root controller
        rootController.initializer(address(ensRegistry));

        // add the role of CONTROLLER_ROLE to the account
        ensRegistry.grantRole(CONTROLLER_ROLE, account);

        fuseController = new FuseController(address(ensRegistry));

        // set up the ETH node. 
        rootController.setSubnode(
            "eth", 
            abi.encodePacked(fuseController, account, resolver, type(uint64).max, uint64(0), address(0)), 
            account
        );

    }

    // test the contract is initialized correctly
    function testInit() public {
        assertEq(ensRegistry.name(), "ENS_RegistryV2");
        assertEq(ensRegistry.symbol(), "ENSV2");
    }

    // make sure a new subnode can be set using a labelhash
    function setSubnode() public {

        // Make the Eth node using the DNS encoded bytes encoded name.
        bytes32 doEthNode = bytes("x03eth\x00").namehash(0); 

        fuseController.setSubnode(doEthNode, "test", account, resolver, type(uint64).max, uint64(0), address(0));

        // Make the test.eth node using the DNS encoded bytes encoded name.
        bytes32 testNode = bytes("x04test\x03eth\x00").namehash(0);

        // Make sure the owner of the test.eth node is the account
        assertEq(fuseController.ownerOf(testNode), account);
    }

}
