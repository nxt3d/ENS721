// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ENS721} from "../contracts/ENS721.sol";
import {RootController} from "../contracts/RootController.sol";
import {IENS721} from "../contracts/IENS721.sol";
import {FuseController} from "../contracts/FuseController.sol";
import {BytesUtils} from "../contracts/BytesUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

error UnsupportedFunction();

contract ENS721Test is Test {

    using BytesUtils for bytes;
    using Strings for uint256;

    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");    

    ENS721 public ensRegistry;
    RootController public rootController;
    FuseController public fuseController;

    // the main account that will be used to test
    address public account = 0x0000000000000000000000000000000000001101;
    address public account2 = 0x0000000000000000000000000000000000002202;
    address public account3 = 0x0000000000000000000000000000000000003303;
    address public resolver = 0x0000000000000000000000000000000000004404; 

    address public dummyAddress = 0x000000000000000000000000000000000000DEFf; 

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

    // Create a Subheading using an empty function.
    function test1000________________________________________________________________________________() public {}
    function test2000__________________________ENS_721_REGISTRY______________________________________() public {}
    function test3000________________________________________________________________________________() public {}



    // make sure a new subnode can be set using a labelhash
    function test_002____setSubnode_______________________setSubnodeOfANode() public {

        // Make the Eth node using the DNS encoded bytes encoded name.
        bytes32 doEthNode = bytes("\x03eth\x00").namehash(0); 

        fuseController.setSubnode(doEthNode, "test", account, resolver, type(uint64).max, uint64(0), address(0));

        // Make the test.eth node using the DNS encoded bytes encoded name.
        bytes32 testNode = bytes("\x04test\x03eth\x00").namehash(0);

        // Make sure the owner of the test.eth node is the account
        assertEq(fuseController.ownerOf(testNode), account);

        // Make sub-sub node
        fuseController.setSubnode(testNode, "subtest", account2, resolver, type(uint64).max, uint64(0), dummyAddress);

        // Make the subtest.test.eth node using the DNS encoded bytes encoded name.
        bytes32 subtestNode = bytes("\x07subtest\x04test\x03eth\x00").namehash(0);

        // Make sure the owner of the subtest.test.eth node is the account
        assertEq(fuseController.renewalControllerOf(subtestNode), dummyAddress);
    }

    function test_003____setBaseURI_______________________setBaseURI() public {
        ensRegistry.setBaseURI("https://api.ens.domains/v1/");
        assertEq(ensRegistry.baseURI(), "https://api.ens.domains/v1/");

        // Add a test node
        bytes32 doEthNode = bytes("\x03eth\x00").namehash(0);
        fuseController.setSubnode(doEthNode, "test", account, resolver, type(uint64).max, uint64(0), address(0));

        // test the uri of the test node
        bytes32 testNode = bytes("\x04test\x03eth\x00").namehash(0);
        uint256 id = uint256(testNode);

        // Make sure the uri of the test.eth node is the account, which is the base node concatenated with the id
        string memory uriAll = string.concat(ensRegistry.baseURI(), id.toString());

        // Get the uri of the test.eth node
        string memory uri = ensRegistry.tokenURI(id);

        // compare the uri of the test.eth node with the uriAll
        assertEq(uri, uriAll);
    }

    // Make sure we can getData
    function test_004____getData__________________________getData() public {
        // Add a test node
        bytes32 doEthNode = bytes("\x03eth\x00").namehash(0);
        fuseController.setSubnode(doEthNode, "test", account, resolver, type(uint64).max, uint64(0), address(0));

        // Get the data of the test.eth node
        bytes memory data = ensRegistry.getData(uint256(bytes("\x04test\x03eth\x00").namehash(0)));

        // encode the data of the test.eth node
        bytes memory dataEncoded = abi.encodePacked(fuseController, account, resolver, type(uint64).max, uint64(0), address(0));

        // Make sure the data of the test.eth node is the same as the dataEncoded
        assertEq(data, dataEncoded);

    }

    // Check to make sure we can get the name of a node
    function test_005____getName__________________________getName() public {
        // Add a test node
        bytes32 doEthNode = bytes("\x03eth\x00").namehash(0);
        fuseController.setSubnode(doEthNode, "test", account, resolver, type(uint64).max, uint64(0), address(0));

        // Get the name of the test.eth node
        bytes memory name = ensRegistry.getName(uint256(bytes("\x04test\x03eth\x00").namehash(0)));

        // Make sure the name of the test.eth node is the same as the name
        assertEq(name, bytes("\x04test\x03eth\x00"));
    }

    // Check to make sure we can get the resolver of the root node
    function test_006____resolver_________________________resolverOfTheRootNodeCanBeSetAndRetrieved() public {

        // Call set resolver on the root node
        rootController.setResolver(resolver);

        // Make sure the resolver of the root node is set, use tokenId 0    
        assertEq(ensRegistry.resolver(0), resolver);

    }

    // Check to make sure that the resolver of the .eth node can be set and retrieved
    function test_007____resolver_________________________resolverOfTheEthNodeCanBeSetAndRetrieved() public {

        // Add a test node
        bytes32 doEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the resolver of the .eth node to the dummy address
        fuseController.setResolver(uint256(doEthNode), dummyAddress);

        // Make sure the resolver of the test.eth node is the same as the resolver
        assertEq(ensRegistry.resolver(uint256(doEthNode)), dummyAddress);
    }

    // Check to make sure it is possible to get the controller of the root node. 
    function test_008____getController____________________getController() public {

        // get the data of the node
        bytes memory data = ensRegistry.getData(0);

        // Get the controller of the root node
        address controller = address(ensRegistry.getController(data));

        // Make sure the controller of the root node is the same as the root controller
        assertEq(controller, address(rootController));
    }

    // Check to make sure it is possible to get the controller of the .eth node.
    function test_009____getController____________________getController() public {
        // Add a test node
        bytes32 doEthNode = bytes("\x03eth\x00").namehash(0);

        // get the data of the node
        bytes memory data = ensRegistry.getData(uint256(doEthNode));

        // Get the controller of the .eth node
        address controller = address(ensRegistry.getController(data));

        // Make sure the controller of the .eth node is the same as the fuse controller
        assertEq(controller, address(fuseController));

    }

    // Check to make sure the balanceOf function reverts with the custom error UnsupportedFunction()
    function test_010____balanceOf________________________balanceOf() public {

        // Make sure the balanceOf function reverts with the custom error UnsupportedFunction()
        vm.expectRevert(abi.encodeWithSelector(UnsupportedFunction.selector)); 
        ensRegistry.balanceOf(account);
    }

    // Check to make sure ownerOf() returns the owner of the .eth node
    function test_011____ownerOf__________________________ownerOf() public {
        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Make sure the owner of the .eth node is the account
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account);

    }

    // test the contract is initialized correctly
    function test_012____name_and_symbol__________________nameAndSymbol() public {
        assertEq(ensRegistry.name(), "ENS_RegistryV2");
        assertEq(ensRegistry.symbol(), "ENSV2");
    }

    // Check to make sure we can get the token URI of the .eth node
    function test_013____tokenURI_________________________tokenURI() public {

        // Set the baseURI
        ensRegistry.setBaseURI("https://api.ens.domains/v1/");

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Get the token URI of the test.eth node
        string memory uri = ensRegistry.tokenURI(uint256(dotEthNode));

        // Make sure the token URI of the test.eth node is the same as the token URI

        // concatinate the baseURI with the id of the node
        string memory uriAll = string.concat(ensRegistry.baseURI(), uint256(dotEthNode).toString());

        assertEq(uri, uriAll);
    }

    // Check to make sure the owner can approve an address to transfer a token
    function test_014____setApprovalAll___________________setOperatorApprovalForToken() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Approve account2 using the approve() function
        ensRegistry.approve(account2, uint256(dotEthNode));

        vm.stopPrank();
        // Change the caller to account2.
        vm.startPrank(account2);

        // Transfer the token from account to account3 using the transferFrom() function
        ensRegistry.transferFrom(account, account3, uint256(dotEthNode));

        // Make sure the owner of the .eth node is the account3
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account3);

        // Get the approved account for the .eth node
        address approvedAccount = ensRegistry.getApproved(uint256(dotEthNode));

        // Make sure the approved account for the .eth node is the cleared
        assertEq(approvedAccount, address(0));
    }


    // Make sure the owner can set an operator approval for a token and transfer the token
    function test_015____setApprovalAll___________________setOperatorApprovalForToken() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the operator approval for the .eth node
        ensRegistry.setApprovalForAll(account2, true);

        // Make sure the operator approval for the .eth node is set using isApprovedForAll
        assert(ensRegistry.isApprovedForAll(account, account2));

        // Transfer the token from account to account3 using the transferFrom() function
        ensRegistry.transferFrom(account, account3, uint256(dotEthNode));

        // Make sure the owner of the .eth node is the account3
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account3);

    }

    // Make sure that isApprovedForAll returns true if the operator is approved for the token
    function test_016____isApprovedForAll_________________isApprovedForAll() public {

        // Set the operator approval for the .eth node
        ensRegistry.setApprovalForAll(account2, true);

        // Make sure the operator approval for the .eth node is set using isApprovedForAll
        assert(ensRegistry.isApprovedForAll(account, account2));

        // Set the operator approval for the .eth node to false
        ensRegistry.setApprovalForAll(account2, false);

        // Make sure the operator approval for the .eth node is not set using isApprovedForAll
        assert(!ensRegistry.isApprovedForAll(account, account2));
    }

    // Make sure the owner can set an operator approval for a token using the function setOperatorApprovalForToken and transfer the token

    function test_017____setOperatorApprovalForToken______setOperatorApprovalForToken() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the operator approval for the .eth node
        ensRegistry.setOperatorApprovalForToken(account, uint256(dotEthNode), account2 , true);

        // Make sure the operator approval for the .eth node is set using isOperatorApprovedForToken
        assert(ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account2));

        vm.stopPrank();
        // Change the caller to account2.
        vm.startPrank(account2);

        // Transfer the token from account to account3 using the transferFrom() function
        ensRegistry.transferFrom(account, account3, uint256(dotEthNode));

        // Make sure the owner of the .eth node is the account3
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account3);
    }

    // Make sure that isOperatorApprovedForToken returns true if the operator is approved for the token
    function test_018____isOperatorApprovedForToken_______isOperatorApprovedForToken() public {


        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the operator approval for the .eth node
        ensRegistry.setOperatorApprovalForToken(account, uint256(dotEthNode), account2 , true);

        // Make sure the operator approval for the .eth node is set using isOperatorApprovedForToken
        assert(ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account2));

    }

    // Make sure that if two operator approvals are set, they can both be cleared using clearTokenOperatorApprovals
    function test_019____clearTokenOperatorApprovals________clearTokenOperatorApprovals() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the operator approval for the .eth node
        ensRegistry.setOperatorApprovalForToken(account, uint256(dotEthNode), account2 , true);

        // Set the operator approval for the .eth node
        ensRegistry.setOperatorApprovalForToken(account, uint256(dotEthNode), account3 , true);

        // Make sure the operator approval for the .eth node is set using isOperatorApprovedForToken
        assert(ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account2));
        assert(ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account3));

        // Clear the operator approval for the .eth node
        ensRegistry.clearTokenOperatorApprovals(account);

        // Make sure the operator approval for the .eth node is not set using isOperatorApprovedForToken
        assert(!ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account2));
        assert(!ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account3));
    }

    // Make sure the owner can transfer the token using the transferFrom function
    function test_020____transferFrom______________________transferFrom() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Transfer the token from account to account3 using the transferFrom() function
        ensRegistry.transferFrom(account, account3, uint256(dotEthNode));

        // Make sure the owner of the .eth node is the account3
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account3);
    }

    // Make sure the owner can transfer the token using the safeTransferFrom function
    function test_021____safeTransferFrom__________________safeTransferFrom() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Transfer the token from account to account3 using the safeTransferFrom() function
        ensRegistry.safeTransferFrom(account, account3, uint256(dotEthNode));

        // Make sure the owner of the .eth node is the account3
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account3);
    }

    // Make sure the owner can transfer the token using the safeTransferFrom function with data
    function test_022____safeTransferFrom__________________safeTransferFrom() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Transfer the token from account to account3 using the safeTransferFrom() function
        ensRegistry.safeTransferFrom(account, account3, uint256(dotEthNode), "data");

        // Make sure the owner of the .eth node is the account3
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account3);
    }

    // Make sure that calling isAuthorized on an authorized account returns true
    function test_023____isAuthorized______________________isAuthorized() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the operator approval for the .eth node
        ensRegistry.setOperatorApprovalForToken(account, uint256(dotEthNode), account2 , true);

        // Make sure the operator approval for the .eth node is set using isOperatorApprovedForToken
        assert(ensRegistry.isOperatorApprovedForToken(account, uint256(dotEthNode), account2));

        // Make sure that calling isAuthorized on an authorized account returns true
        assert(ensRegistry.isAuthorized(account, account2, uint256(dotEthNode)));
    }

    // Make sure that calling isAuthorized on an authorized account returns true, using the approve function
    function test_024____isAuthorized______________________isAuthorized() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Authorize account2 to transfer the .eth node
        ensRegistry.approve(account2, uint256(dotEthNode));

        // Make sure that calling isAuthorized on an authorized account returns true
        assert(ensRegistry.isAuthorized(account, account2, uint256(dotEthNode)));
    }

    // Make sure that calling isAuthorized on an authorized account returns true, using the setApprovalForAll function
    function test_025____isAuthorized______________________isAuthorized() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the operator approval for the .eth node
        ensRegistry.setApprovalForAll(account2, true);

        // Make sure that calling isAuthorized on an authorized account returns true
        assert(ensRegistry.isAuthorized(account, account2, uint256(dotEthNode)));
    }

    // Make sure that calling isAuthorized on an the owner returns true
    function test_026____isAuthorized______________________isAuthorized() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Make sure that calling isAuthorized on an the owner returns true
        assert(ensRegistry.isAuthorized(account, account, uint256(dotEthNode)));
    }

    // Use the setOwner function on the .eth node to set the owner to account2
    // This will call the setNode function in the ENS Registry
    function test_027____setNode___________________________setNode() public {

        // Add a test node
        bytes32 dotEthNode = bytes("\x03eth\x00").namehash(0);

        // Set the owner of the .eth node to account2
        fuseController.setOwner(dotEthNode, account2);

        // Make sure the owner of the .eth node is the account2
        assertEq(ensRegistry.ownerOf(uint256(dotEthNode)), account2);
    }






}
