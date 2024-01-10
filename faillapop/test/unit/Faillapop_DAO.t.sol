// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_Shop} from "../../src/Faillapop_shop.sol";
import {FP_Vault} from "../../src/Faillapop_vault.sol";

contract Faillapop_DAO_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;

    address public constant NFT_ADDRESS = address(1);
    address public constant FPT_ADDRESS = address(2);
    address public constant SELLER1 = address(3);
    address public constant BUYER1 = address(4);

    /************************************* Modifiers *************************************/

    modifier createLegitSale(){
        // Simulate an user's stake in the Vault
        vm.prank(SELLER1);
        vault.doStake{value: 2 ether}();

        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        shop.newSale(title, description, price);
        _;
    }

    modifier buyLastItem(){
        uint256 saleId = shop.offerIndex() - 1;
        vm.prank(BUYER1);
        shop.doBuy{value: 1 ether}(saleId);
        _;
    }

    modifier disputeSale(){
        vm.prank(BUYER1);
        shop.disputeSale(0, "Buyer's reasoning");
        _;
    }
    modifier replyDisputedSale(){
        vm.prank(SELLER1);
        shop.disputedSaleReply(0, "Seller's reasoning");
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(SELLER1, 10 ether);
        vm.deal(BUYER1, 10 ether);

        dao = new FP_DAO("password", NFT_ADDRESS, FPT_ADDRESS);
        vault = new FP_Vault(FPT_ADDRESS, address(dao));
        shop = new FP_Shop(address(dao), address(vault));
        vault.setShop(address(shop));
        dao.setShop(address(shop));
    }

    /************************************** Tests **************************************/  

    function test_SetShop() public {
        assertTrue(dao.hasRole(bytes32(dao.CONTROL_ROLE()), address(shop)));
        assertEq(address(dao.shopContract()), address(shop));
    }   

    function test_updateConfig_Password() public {
        // Update password
        dao.updateConfig("password", "password2", address(shop), NFT_ADDRESS);

        // This revert is expected because the password has been correctly updated
        vm.expectRevert(bytes("Unauthorized"));
        dao.updateConfig("password", "password2", address(shop), NFT_ADDRESS);

        // The ausence of revert means that the password has been correctly updated
        dao.updateConfig("password2", "password2", address(shop), NFT_ADDRESS);
    }

    function test_updateConfig_RevertIf_IncorrectPassword() public {
        // Update password with incorrect password
        vm.expectRevert(bytes("Unauthorized"));
        dao.updateConfig("Qwerty*", "password2", address(shop), NFT_ADDRESS);
    }

    function test_updateConfig_RevertIf_ShopAddressIsZero() public {
        // Update shop address with zero address
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        dao.updateConfig("password", "password", address(0), NFT_ADDRESS);
    }

    function test_updateConfig_RevertIf_NftAddressIsZero() public {
        // Update nft address with zero address
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        dao.updateConfig("password", "password", address(shop), address(0));
    }

    function test_newDispute() public createLegitSale() buyLastItem() disputeSale() {
        // Save dispute before creation
        FP_DAO.Dispute memory disputeBefore = dao.queryDispute(0);
        assertEq(disputeBefore.itemId, 0, "Wrong itemId");
        assertEq(disputeBefore.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(disputeBefore.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(disputeBefore.votesFor, 0, "Wrong votesFor");
        assertEq(disputeBefore.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(disputeBefore.totalVoters, 0, "Wrong totalVoters");

        // Create dispute
        vm.prank(SELLER1);
        shop.disputedSaleReply(0, "Seller's reasoning");
        // Check the dispute creation
        FP_DAO.Dispute memory disputeAfter = dao.queryDispute(0);
        assertEq(disputeAfter.itemId, 0, "Wrong itemId, dispute creation failed");
        assertEq(disputeAfter.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning, dispute creation failed");
        assertEq(disputeAfter.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning, dispute creation failed");
        assertEq(disputeAfter.votesFor, 0, "Wrong votesFor, dispute creation failed");
        assertEq(disputeAfter.votesAgainst, 0, "Wrong votesAgainst, dispute creation failed");
        assertEq(disputeAfter.totalVoters, 0, "Wrong totalVoters, dispute creation failed");
    }
    function test_newDispute_RevertIf_CallerIsNotTheShop() public createLegitSale() buyLastItem() disputeSale() {
        // Create dispute with unauthorized account
        vm.prank(SELLER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(SELLER1), keccak256("CONTROL_ROLE")));
        dao.newDispute(0, "Buyer's reasoning", "Seller's reasoning");
    }

    function test_endDispute_RevertIf_NotEnoughUsersVoted() public createLegitSale() buyLastItem() disputeSale() { 
        // Check endDispute without enough votes
        vm.expectRevert(bytes("Not enough voters"));
        dao.endDispute(0);
    }
    
    function test_cancelDispute() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        vm.prank(address(shop));
        dao.cancelDispute(0);
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
    }
    function test_cancelDispute_RevertIf_CallerIsNotTheShop() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        vm.prank(SELLER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(SELLER1), keccak256("CONTROL_ROLE")));
        dao.cancelDispute(0);
    }

    function test_checkLottery_RevertIf_UserHasNotVoted() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Check lottery without voting
        vm.expectRevert(bytes("User didn't vote"));
        dao.checkLottery(0);
    }

}