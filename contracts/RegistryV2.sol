// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ENS721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract RegistryV2 is ENS721, AccessControl {

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    constructor() ENS721("ENS_RegistryV2", "ENSV2") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 tokenId) external onlyRole(CONTROLLER_ROLE){
        _mint(to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ENS721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
