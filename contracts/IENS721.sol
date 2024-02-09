// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IController} from "./IController.sol";


interface IENS721 is IERC721, IERC721Metadata, IERC721Errors {


    // a nonce for each owner to be able to revoke a token token operator approvals
    function tokenOperatorApprovalsNonce(address owner) external view returns (uint256);

    function setBaseURI(string memory _baseURI) external;

    function getData(uint256 tokenId) external view returns (bytes memory);

    function getName(uint256 tokenId) external view returns (bytes memory);

    function resolver(uint256 tokenId) external view returns (address /*resolver*/);

    function getController(
        bytes memory data
    ) external pure returns (IController addr);

    function clearTokenOperatorApprovals(address owner) external;

    function setOperatorApprovalForToken(address owner,  uint256 tokenId, address operator, bool approved) external;

    function isOperatorApprovedForToken(address owner, uint256 tokenId, address operator) external view returns (bool); 

    function setNode(uint256 tokenId, bytes memory data) external;

    function setSubnode(
        uint256 tokenId,
        string memory label,
        bytes memory subnodeData,
        address to
    ) external;

    function isAuthorized(address owner, address spender, uint256 tokenId) external view returns (bool);

}
