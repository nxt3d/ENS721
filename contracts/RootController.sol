// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./IController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IENS721} from "./IENS721.sol";

import "forge-std/console2.sol";

error LabelTooShort();
error LabelTooLong(string label);

contract RootController is Ownable, IController {
    address resolver;
    address registry;

    bytes32 private constant ROOT_NODE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    constructor(address _resolver) Ownable(msg.sender) {
        resolver = _resolver;
    }

    function initializer(address _registry) public onlyOwner{
        if (registry != address(0)) {
            revert("Already initialized");
        }
        registry = _registry;
    }

    error CannotTransfer();

    event NewResolver(uint256 id, address resolver);

    /*************************
     * IController functions *
     *************************/

    function ownerOfWithData(
        bytes calldata /*tokenData*/
    ) external view returns (address) {
        return owner();
    }

    function ownerOf(bytes32 /*node*/) external view returns (address) {
        return owner();
    }

    function resolverFor(
        bytes calldata /*tokenData*/
    ) external view returns (address) {
        return resolver;
    }

    // an update function that takes tokenData as an argument
    function update(
        bytes32 ,
        bytes calldata ,
        address 
    ) external {

        // This is just a dummy function to satisfy the interface
 
    }

    /*******************
     * Owner functions *
     *******************/
    function setResolver(address newResolver) external onlyOwner {
        resolver = newResolver;
        emit NewResolver(0, newResolver);
    }

    function setSubnode(
        string calldata label,
        bytes calldata subnodeData,
        address to
    ) external onlyOwner {

        IENS721(registry).setSubnode(
            uint256(ROOT_NODE),
            label,
            subnodeData,
            to
        );
    }

    function _addLabel(
        string memory label,
        bytes memory name
    ) internal pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }
        return abi.encodePacked(uint8(bytes(label).length), label, name);
    }
}
