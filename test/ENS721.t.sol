// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ENS721} from "../contracts/ENS721.sol";

contract ENS721Test is Test {
    ENS721 public ens721;

    function setUp() public {
        ens721 = new ENS721("test", "TST");
    }

    // test the contract is initialized correctly
    function testInit() public {
        assertEq(ens721.name(), "test");
        assertEq(ens721.symbol(), "TST");
    }


}
