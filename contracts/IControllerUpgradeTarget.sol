// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./IController.sol";

interface IControllerUpgradeTarget is IController {
    function upgradeFrom(bytes32 node, bytes calldata extraData) external;
}
