// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/Faillapop_CoolNFT.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_PowersellerNFT} from "../../src/Faillapop_PowersellerNFT.sol";
import {FP_Shop} from "../../src/Faillapop_shop.sol";
import {FP_Token} from "../../src/Faillapop_ERC20.sol";
import {FP_Vault} from "../../src/Faillapop_vault.sol";

contract Faillapop_DAO_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;
    FP_Token public token;
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;

    address public constant USER1 = address(1);
    address public constant USER2 = address(2);
    address public constant SELLER1 = address(3);
    address public constant BUYER1 = address(4);

    /************************************* Modifiers *************************************/

    modifier createLegitSale() {
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

    modifier buyLastItem() {
        uint256 saleId = shop.offerIndex() - 1;
        vm.prank(BUYER1);
        shop.doBuy{value: 1 ether}(saleId);
        _;
    }

    modifier disputeSale() {
        vm.prank(BUYER1);
        shop.disputeSale(0, "Buyer's reasoning");
        _;
    }
    modifier replyDisputedSale() {
        vm.prank(SELLER1);
        shop.disputedSaleReply(0, "Seller's reasoning");
        _;
    }

    modifier mintAndVote(bool vote) {
        // Mint FP_tokens
        uint amount = 1000;
        token.mint(address(USER1), amount);
        assertEq(token.balanceOf(address(USER1)), amount, "Wrong balance");
        
        // Cast vote
        vm.prank(USER1);
        dao.castVote(0, vote);
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(SELLER1, 10 ether);
        vm.deal(BUYER1, 10 ether);
        vm.deal(USER1, 10 ether);
        vm.deal(USER2, 10 ether);

        token = new FP_Token();
        coolNFT = new FP_CoolNFT();
        powersellerNFT = new FP_PowersellerNFT();
        dao = new FP_DAO("password", address(coolNFT), address(token));
        vault = new FP_Vault(address(powersellerNFT), address(dao));
        shop = new FP_Shop(address(dao), address(vault), address(powersellerNFT));

        vault.setShop(address(shop));
        dao.setShop(address(shop));
        powersellerNFT.setShop(address(shop));
        coolNFT.setDAO(address(dao));
    }

    /************************************** Tests **************************************/  

    function test_SetShop() public {
        assertTrue(dao.hasRole(bytes32(dao.CONTROL_ROLE()), address(shop)));
        assertEq(address(dao.shopContract()), address(shop));
    }     

    function test_setShop_x2() public {
        vm.prank(address(shop));
        vm.expectRevert(bytes("Shop address already set"));
        dao.setShop(address(shop));
    } 

    function test_updateConfig_Password() public {
        // Update password
        dao.updateConfig("password", "password2", address(shop), address(coolNFT));

        // This revert is expected because the password has been correctly updated
        vm.expectRevert(bytes("Unauthorized"));
        dao.updateConfig("password", "password2", address(shop), address(coolNFT));

        // The ausence of revert means that the password has been correctly updated
        dao.updateConfig("password2", "password2", address(shop), address(coolNFT));
    }

    function test_updateConfig_RevertIf_IncorrectPassword() public {
        // Update password with incorrect password
        vm.expectRevert(bytes("Unauthorized"));
        dao.updateConfig("Qwerty*", "password2", address(shop), address(coolNFT));
    }

    function test_updateConfig_RevertIf_ShopAddressIsZero() public {
        // Update shop address with zero address
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        dao.updateConfig("password", "password", address(0), address(coolNFT));
    }

    function test_updateConfig_RevertIf_NftAddressIsZero() public {
        // Update nft address with zero address
        vm.expectRevert(abi.encodeWithSignature("ZeroAddress()"));
        dao.updateConfig("password", "password", address(shop), address(0));
    }

    function test_castVote_VoteFor() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        // Check vote
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        assertEq(uint(dao.hasVoted(address(USER1), 0)), uint(FP_DAO.Vote.FOR),"Wrong hasVoted");
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 1000, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 1, "Wrong totalVoters");
    }

    function test_castVote_VoteAgainst() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(false) {
        // Check vote
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 1000, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 1, "Wrong totalVoters");
    }

    function test_castVote_2Votes() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        uint amount2 = 13000;
        token.mint(address(USER2), amount2);
        assertEq(token.balanceOf(address(USER2)), amount2, "Wrong balance");
    
        vm.prank(USER2);
        dao.castVote(0, true);

        // Check vote
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);        
        assertEq(uint(dao.hasVoted(address(USER1), 0)), uint(FP_DAO.Vote.FOR),"Wrong hasVoted");
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 1000 + amount2, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 2, "Wrong totalVoters");
    }

    function test_castVote_RevertIf_UserHasNoTokens() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Cast vote
        vm.expectRevert(bytes("You have no voting power"));
        vm.prank(USER1);
        dao.castVote(0, true);
    }
    
    function test_castVote_RevertIf_UserHasAlreadyVoted() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        vm.expectRevert(bytes("You have already voted"));
        vm.prank(USER1);
        dao.castVote(0, true);
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

    function test_endDispute_VotesFor() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        dao.endDispute(0);
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        FP_DAO.Vote result = dao.queryDisputeResult(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint(result), uint(FP_DAO.Vote.FOR), "Wrong result");
    }

    function test_endDispute_VotesAgainst() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(false) {
        dao.endDispute(0);
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        FP_DAO.Vote result = dao.queryDisputeResult(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint(result), uint(FP_DAO.Vote.AGAINST), "Wrong result");
    }

    function test_endDispute_EqualVotes() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        uint amount = 1000;
        token.mint(address(USER2), amount);
        assertEq(token.balanceOf(address(USER2)), amount, "Wrong balance");
        vm.prank(USER2);
        dao.castVote(0, false);

        // Check endDispute with enough votes
        dao.endDispute(0);
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        FP_DAO.Vote result = dao.queryDisputeResult(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint(result), uint(FP_DAO.Vote.AGAINST), "Wrong result");
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

    function test_checkLottery() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        dao.endDispute(0);
        
        vm.prank(USER1);
        dao.checkLottery(0);
        assertTrue(dao.hasCheckedLottery(USER1, 0));
    }

    function test_checkLottery_RevertIf_UserHasVotedToTheWrongSide() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(false) {
        uint amount2 = 130;
        token.mint(address(USER2), amount2);
        vm.prank(USER2);
        dao.castVote(0, true);
        
        dao.endDispute(0);
        
        vm.expectRevert(bytes("User voted for the wrong side"));
        vm.prank(USER2);
        dao.checkLottery(0);
    }
    
    function test_checkLottery_RevertIf_UserHasAlreadyCheckedIt() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndVote(true) {
        dao.endDispute(0);
        
        vm.prank(USER1);
        dao.checkLottery(0);

        vm.expectRevert(bytes("User cannot check the lottery more than 1 time per dispute"));
        vm.prank(USER1);
        dao.checkLottery(0);
    }

    function test_checkLottery_RevertIf_UserHasNotVoted() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Check lottery without voting
        vm.expectRevert(bytes("User didn't vote"));
        vm.prank(USER1);
        dao.checkLottery(0);
    }

}