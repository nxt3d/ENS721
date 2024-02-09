// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {IENS721} from "./IENS721.sol";
import {IFuseController} from "./IFuseController.sol";
import {IControllerUpgradeTarget} from "./IControllerUpgradeTarget.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {BytesUtils} from "./BytesUtils.sol";
import {IController} from "./IController.sol";

import "forge-std/console2.sol";

error Unauthorised(bytes32 node, address addr);
error CannotUpgrade();
error nameExpired(bytes32 node);
error LabelTooShort();
error LabelTooLong(string label);

/**
 * @dev A simple ENS registry controller. Names are permanently owned by a single account.
 *      Name data is structured as follows:
 *       - Byte 0: controller (address)
 *       - Byte 20: owner (address)
 *       - Byte 40: resolver (address)
 *       _ Byte 60: expiry (uint64)
 *       - Byte 68: fuses (uint64)
 *       - Byte 76: renewalController (address)
 */
contract FuseController is AccessControl, IFuseController {

    using BytesUtils for bytes;

    IENS721 immutable registry;

    IControllerUpgradeTarget upgradeContract;

    event NewController(bytes32 node, address controller);

    // A struct to hold the unpacked data
    struct TokenData {
        address owner;
        address resolver;
        uint64 expiry;
        uint64 fuses;
        address renewalController;
    }

    constructor(address _registry) {
        registry = IENS721(_registry);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*************************
     * IController functions *
     *************************/

    function ownerOfWithData(
        bytes calldata tokenData
    ) external pure returns (address) {
        (address owner, , , , ) = _unpack(tokenData);
        return owner;
    }

    function ownerOf(bytes32 node) public view returns (address) {
        //get the tokenData
        bytes memory tokenData = registry.getData(uint256(node));
        (address owner, , , , ) = _unpack(tokenData);
        return owner;
    }

    function balanceOf(
        bytes calldata tokenData,
        address _owner,
        uint256 /*id*/
    ) external pure returns (uint256) {
        (address owner, , , , ) = _unpack(tokenData);
        return _owner == owner ? 1 : 0;
    }

    function resolverFor(
        bytes calldata tokenData
    ) external pure returns (address) {
        (, address resolver, , , ) = _unpack(tokenData);
        return resolver;
    }

    function expiryOf(bytes32 node) external view returns (uint64) {
        // get the tokenData
        bytes memory tokenData = registry.getData(uint256(node));
        (, , uint64 expiry, , ) = _unpack(tokenData);
        return expiry;
    }

    function fusesOf(bytes32 node) external view returns (uint64) {
        // get the tokenData
        bytes memory tokenData = registry.getData(uint256(node));
        (, , , uint64 fuses, ) = _unpack(tokenData);
        return fuses;
    }

    function renewalControllerOf(bytes32 node) external view returns (address) {
        // get the tokenData
        bytes memory tokenData = registry.getData(uint256(node));
        (, , , , address renewalController) = _unpack(tokenData);
        return renewalController;
    }

    function upgrade(bytes32 node, bytes calldata extraData) public {
        // Make sure the upgrade contract is set.
        if (address(upgradeContract) == address(0)) {
            revert CannotUpgrade();
        }

        // Unpack the tokenData of the node.
        bytes memory tokenData = registry.getData(uint256(node));
        (
            address owner,
            address resolver,
            uint64 expiry,
            uint64 fuses,
            address renewalController
        ) = _unpack(tokenData);

        bool isAuthorized = registry.isAuthorized(
            owner,
            msg.sender,
            uint256(node)
        );

        if (owner != msg.sender && !isAuthorized) {
            revert Unauthorised(node, msg.sender);
        }

        if (_isExpired(tokenData)) {
            revert nameExpired(node);
        }

        // Change the controller to the upgrade contract.
        registry.setNode(
            uint256(node),
            _pack(
                address(upgradeContract),
                owner,
                resolver,
                expiry,
                fuses,
                renewalController
            )
        );

        // Call the new contract to notify it of the upgrade.
        upgradeContract.upgradeFrom(node, extraData);
    }

    // an update function that takes tokenData as an argument
    function update(
        bytes32 node,
        bytes calldata tokenData,
        address to
    ) external {

        // Only the registry can call this function
        require(msg.sender == address(registry), "Not the registry");

        (
            ,
            address resolver,
            uint64 expiry,
            uint64 fuses,
            address renewalController
        ) = _unpack(tokenData);

        registry.setNode(
            uint256(node),
            _pack(
                address(this),
                to,
                resolver,
                expiry,
                fuses,
                renewalController
            )
        );
    }


    /*******************
     * Node Owner functions *
     *******************/

    function setResolver(uint256 tokenId, address newResolver) external {
        // get tokenData
        bytes memory tokenData = registry.getData(tokenId);
        (
            address owner,
            ,
            uint64 expiry,
            uint64 fuses,
            address renewalController
        ) = _unpack(tokenData);
        bool isAuthorized = registry.isAuthorized(owner, msg.sender, tokenId);

        if (owner != msg.sender && !isAuthorized) {
            revert Unauthorised(bytes32(tokenId), msg.sender);
        }

        registry.setNode(
            tokenId,
            _pack(
                address(this),
                owner,
                newResolver,
                expiry,
                fuses,
                renewalController
            )
        );
    }

    function setSubnode(
        bytes32 node,
        string memory label,
        address subnodeOwner,
        address subnodeResolver,
        uint64 subnodeExpiry,
        uint64 subnodeFuses,
        address subnodeRenewalController
    ) external {

        // In order to set the subnode the msg.sender must be the owner of the node or be authorized by the owner.
        bytes memory tokenData = registry.getData(uint256(node));
        (address owner, , , , ) = _unpack(tokenData);
        bool isAuthorized = registry.isAuthorized(
            owner,
            msg.sender,
            uint256(node)
        );

        if (owner != msg.sender && !isAuthorized) {
            revert Unauthorised(node, msg.sender);
        }

        registry.setSubnode(
            uint256(node),
            label,
            _pack(
                address(this),
                subnodeOwner,
                subnodeResolver,
                subnodeExpiry,
                subnodeFuses,
                subnodeRenewalController
            ),
            subnodeOwner
        );
    }

    // a function to set the owner of a node
    function setOwner(bytes32 node, address newOwner) external {
        // get tokenData
        bytes memory tokenData = registry.getData(uint256(node));
        (
            address owner,
            address resolver,
            uint64 expiry,
            uint64 fuses,
            address renewalController
        ) = _unpack(tokenData);

        bool isAuthorized = registry.isAuthorized(owner, msg.sender, uint256(node));

        if (owner != msg.sender && !isAuthorized) {
            revert Unauthorised(node, msg.sender);
        }

        registry.setNode(
            uint256(node),
            _pack(
                address(this),
                newOwner,
                resolver,
                expiry,
                fuses,
                renewalController
            )
        );
    }

    /*******************
     * Owner only functions *
     *******************/

    // A function that sets the upgrade contract.
    function setUpgradeController(
        IControllerUpgradeTarget _upgradeContract
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        upgradeContract = _upgradeContract;
    }

    /**********************
     * Internal functions *
     **********************/

    function _isExpired(bytes memory tokenData) internal view returns (bool) {
        (, , uint64 expiry, , ) = _unpack(tokenData);
        return expiry <= block.timestamp;
    }

    function _unpack(
        bytes memory tokenData
    )
        internal
        pure
        returns (
            address owner,      
            address resolver,  
            uint64 expiry,     
            uint64 fuses,       
            address renewalController 
        )
    {

        uint256 tokenDataLength = tokenData.length;

        // If the tokenData has not been set yet, return the default values.
        if (tokenDataLength != 96) {
            return (address(0), address(0), 0, 0, address(0));
        }

        // Check the length and only unpack the data that is present.
        assembly {
            owner := mload(add(tokenData, 40))
            resolver := mload(add(tokenData, 60))
            expiry := mload(add(tokenData, 68))
            fuses := mload(add(tokenData, 76))
            renewalController := mload(add(tokenData, 96))
        }

    }

    function _pack(
        address controller,
        address owner,
        address resolver,
        uint64 expiry,
        uint64 fuses,
        address renewalController
    ) internal pure returns (bytes memory /*tokenData*/) {
        return
            abi.encodePacked(
                controller,
                owner,
                resolver,
                expiry,
                fuses,
                renewalController
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

    function getController(
        bytes memory data
    ) public pure returns (IController addr) {
        if (data.length < 20) {
            return IController(address(0));
        }
        assembly {
            addr := mload(add(data, 20))
        }
    }

}

