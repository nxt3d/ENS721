// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IController {
    function ownerOfWithData(
        bytes calldata tokenData
    ) external view returns (address);

    function ownerOf(bytes32 node) external view returns (address);

    function resolverFor(
        bytes calldata tokenData
    ) external view returns (address);

    function update(
        bytes32 node,
        bytes calldata tokenData,
        address to
    ) external;
}
