// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IERC165, ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IController} from "./IController.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "forge-std/console2.sol";

error UnsupportedFunction();
error LabelTooShort();
error LabelTooLong(string label);

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ENS721 is Context, ERC165, AccessControl, Pausable, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    struct Record {
        bytes name;
        bytes data;
    }

    string public baseURI;

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Token name
    string public _name;

    // Token symbol
    string public _symbol;

    mapping(uint256 tokenId => Record) private _tokens;

    mapping(address owner => uint256) private _balances;

    mapping(uint256 tokenId => address) private _tokenApprovals;

    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    mapping(address owner => mapping( uint256 nonce => mapping(uint256 id => mapping(address operator => bool)))) private _tokenOperatorApprovals;

    // a nonce for each owner to be able to revoke a token token operator approvals
    mapping(address owner => uint256) public tokenOperatorApprovalsNonce;

    event NewController(uint256 id, address controller);

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_, address rootController) {
        _name = name_;
        _symbol = symbol_;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CONTROLLER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);

        // Setup the root node data. 
        _tokens[0].data = abi.encodePacked(rootController, msg.sender, uint64(0), uint64(0), address(0));

        // Setup the root node name.
        _tokens[0].name = (bytes("\x00"));
    }

    function setBaseURI(string memory _baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = _baseURI;
    }

    function getData(uint256 tokenId) public view returns (bytes memory) {
        return _tokens[tokenId].data;
    }

    function getName(uint256 tokenId) public view returns (bytes memory) {
        return _tokens[tokenId].name;
    }

    function resolver(uint256 id) external view returns (address /*resolver*/) {
        bytes memory tokenData = _tokens[id].data;
        IController _controller = getController(tokenData);
        return _controller.resolverFor(tokenData);
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

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165, AccessControl) virtual returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     WE DO NOT NEED THIS FUNCTION
     */
    function balanceOf(address ) public pure  returns (uint256) {
        revert UnsupportedFunction();
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view  returns (address) {
        return _requireOwned(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view returns (string memory) {
        _requireOwned(tokenId);

        string memory _baseURI = baseURI;
        return bytes(_baseURI).length > 0 ? string.concat(_baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public  {
        _approve(to, tokenId, _msgSender());
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public  {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Sets or revokes approval for a specific operator to manage a specific token.
     * @param owner The address of the owner.
     * @param operator The address of the operator to set or revoke approval for.
     * @param tokenId The ID of the token to set or revoke approval for.
     * @param approved A boolean indicating whether to approve or revoke the operator's approval.
     */

    function setOperatorApprovalForToken(address owner, uint256 tokenId, address operator, bool approved) public {

        // Check to make sure the sender is either the owner or an approved operator.
        if (_msgSender() != owner && !_operatorApprovals[owner][_msgSender()]) {
            revert ERC721InvalidOperator(_msgSender());
        }
        _tokenOperatorApprovals[owner][tokenOperatorApprovalsNonce[owner]][tokenId][operator] = approved;
    }

    /**
     * @dev Returns whether the specified operator is approved to manage the given token on behalf of the owner.
     * @param owner The address of the token owner.
     * @param tokenId The ID of the token.
     * @param operator The address of the operator.
     * @return A boolean value indicating whether the operator is approved.
     */

    function isOperatorApprovedForToken(address owner, uint256 tokenId, address operator) public view returns (bool) {
        return _tokenOperatorApprovals[owner][tokenOperatorApprovalsNonce[owner]][tokenId][operator];
    }

    /**
     * @dev Clears the operator approvals for a given owner.
     * @param owner The address of the owner.
     */

    function clearTokenOperatorApprovals(address owner) public {

        // Check to make sure the sender is either the owner or an approved operator.
        if (_msgSender() != owner && !_operatorApprovals[owner][_msgSender()]) {
            revert ERC721InvalidOperator(_msgSender());
        }
        tokenOperatorApprovalsNonce[owner]++;
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public whenNotPaused{
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public whenNotPaused{
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function isAuthorized(address owner, address spender, uint256 tokenId) public view returns (bool) {
        return
            spender != address(0) &&
            (
                owner == spender || 
                isApprovedForAll(owner, spender) || 
                _getApproved(tokenId) == spender || 
                isOperatorApprovedForToken(owner, tokenId, spender)
            );
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view returns (address) {
        bytes memory tokenData = _tokens[tokenId].data;
        IController _controller = getController(_tokens[tokenId].data); 

        if (address(_controller) == address(0)) {
            return address(0);
        }
        return _controller.ownerOfWithData(tokenData);
    }

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @dev Checks if `spender` can operate on `tokenId`, assuming the provided `owner` is the actual owner.
     * Reverts if `spender` does not have approval from the provided `owner` for the given token or for all its assets
     * the `spender` for the specific `tokenId`.
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view {
        if (!isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal returns (address) {
        address from = _ownerOf(tokenId);

        // get the token data
        bytes memory tokenData = _tokens[tokenId].data;

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);
        }

        IController _controller = getController(_tokens[tokenId].data);

        _controller.update(bytes32(tokenId), tokenData, to);

        emit Transfer(from, to, tokenId);

        return from;
    }


    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        
        bytes memory tokenData = _tokens[tokenId].data;
        IController _controller = getController(tokenData);
        address owner = _controller.ownerOfWithData(tokenData);

        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }


    /*****************************
     * Controller-only functions *
     *****************************/

    function setNode(uint256 tokenId, bytes memory data) external {
        // Fetch the current controller for this node
        IController oldController = getController(_tokens[tokenId].data);

        // Only the controller may call this function
        require(address(oldController) == msg.sender, "Caller is not the controller");

        // Fetch the new controller and emit `NewController` if needed.
        IController newController = getController(data);
        if (oldController != newController) {
            emit NewController(tokenId, address(newController));
        }

        // Update the data for this node.
        _tokens[tokenId].data = data;
    }

    function setSubnode(
        uint256 tokenId,
        string memory label,
        bytes memory subnodeData,
        address to
    ) external {

        // Fetch the token data and controller for the current node
        IController _controller = getController(_tokens[tokenId].data);

        // Only the controller of the node may call this function
        require(address(_controller) == msg.sender, "Caller is not the controller");

        // Get the name of the node, if the name is empty revert the transaction.
        bytes memory nameNode = getName(tokenId);

        if (nameNode.length == 0) {
            revert("Name not found");
        }

        // Make the DNS encoded name of the subnode
        bytes memory subName = _addLabel(label, nameNode);

        // Make a labelhash from the label
        bytes32 labelhash = keccak256(abi.encodePacked(label));

        // Make a subnode from the labelhash and the node
        bytes32 subnode = keccak256(abi.encodePacked(tokenId, labelhash));

        // Set the name of the subnode.
         _tokens[uint256(subnode)].name = subName;

        // Get the the data of the subnode. 
        bytes memory oldSubnodeData = _tokens[uint256(subnode)].data;
        IController oldSubnodeController = getController(oldSubnodeData);
        address oldOwner = oldSubnodeData.length < 20
            ? address(0)
            : oldSubnodeController.ownerOfWithData(oldSubnodeData);

        // Get the address of the new controller
        IController newSubnodeController = getController(subnodeData);
        if (newSubnodeController != oldSubnodeController) {
            emit NewController(uint256(subnode), address(newSubnodeController));
        }

        _tokens[uint256(subnode)].data = subnodeData;

        // If the to address is 0 and the data has an address, use the address in the data.
        if (to == address(0) && subnodeData.length >= 20) {
            to = newSubnodeController.ownerOfWithData(subnodeData);
        }

        emit Transfer(oldOwner, to, tokenId);

    }

    /*******************
     * Utility functions *
     *******************/

    function _addLabel(
        string memory label,
        bytes memory nameNode
    ) internal pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }
        return abi.encodePacked(uint8(bytes(label).length), label, nameNode);
    }

}
