// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/FP_CoolNFT.sol";
import {FP_DAO} from "../../src/FP_DAO.sol";
import {IFP_DAO} from "../../src/interfaces/IFP_DAO.sol";
import {FP_PowersellerNFT} from "../../src/FP_PowersellerNFT.sol";
import {FP_Shop} from "../../src/FP_Shop.sol";
import {FP_Token} from "../../src/FP_Token.sol";
import {FP_Vault} from "../../src/FP_Vault.sol";
import {FP_Proxy} from "../../src/FP_Proxy.sol";
import {DeployFaillapop} from "../../script/DeployFaillapop.s.sol";

contract FP_DAO_Test is Test {
    ///@notice The time window in which a proposal can not be voted
    uint256 public constant PROPOSAL_REVIEW_TIME = 1 days;
    ///@notice The minimum voting period for a proposal
    uint256 public constant PROPOSAL_VOTING_TIME = 3 days;
    ///@notice The minimum waiting time between approval and execution of a proposal
    uint256 public constant PROPOSAL_EXECUTION_DELAY = 1 days;
    ///@notice the minimum committing period for votes on a dispute
    uint256 constant COMMITTING_TIME = 3 days;
    ///@notice The minimum revealing period for votes on a dispute
    uint256 constant MIN_REVEALING_TIME = 1 days;
    ///@notice The maximum revealing period for votes on a dispute
    uint256 constant MAX_REVEALING_TIME = 3 days;
    address public constant USER1 = address(bytes20("USER1"));
    address public constant USER2 = address(bytes20("USER2"));
    address public constant SELLER1 = address(bytes20("SELLER1"));
    address public constant BUYER1 = address(bytes20("BUYER1"));

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;
    FP_Token public token;
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;
    FP_Proxy public proxy;

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
        (bool success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "newSale(string,string,uint256)",
                title, 
                description, 
                price
            )
        );
        require(success, "Sale not created");
        _;
    }

    modifier buyLastItem() {
        (bool success, bytes memory data) = address(proxy).call(
                abi.encodeWithSignature(
                    "offerIndex()" 
                )
            );
        require(success, "Offer index not retrieved");
        uint256 saleId = abi.decode(data, (uint256)) - 1;

        vm.prank(BUYER1);
        (bool success2, ) = address(proxy).call{value: 1 ether}(
            abi.encodeWithSignature(
                "doBuy(uint256)",
                saleId
            )
        );
        require(success2, "Sale not bought");
        _;
    }

    modifier disputeSale() {
        vm.prank(BUYER1);
        (bool success,) = address(proxy).call(
                abi.encodeWithSignature(
                    "disputeSale(uint256,string)",
                    0,
                    "Buyer's reasoning" 
                )
            );
        require(success, "Sale not disputed");
        _;
    }

    modifier replyDisputedSale() {
        vm.prank(SELLER1);
        (bool success,) = address(proxy).call(
                abi.encodeWithSignature(
                    "disputedSaleReply(uint256,string)",
                    0,
                    "Seller's reasoning" 
                )
            );
        require(success, "Disputed sale not replied");
        _;
    }

    modifier mintAndCommitVote(bool vote, string memory secret) {
        // Mint FP_tokens
        uint amount = 1000;
        vm.prank(vm.envAddress("DEPLOYER"));
        token.mint(address(USER1), amount);
        assertEq(token.balanceOf(address(USER1)), amount, "Wrong balance");
        
        // Commit vote
        bytes32 commit = keccak256(abi.encodePacked(vote, secret));
        vm.prank(USER1);
        dao.commitVoteOnDispute(0, commit);
        _;
    }

    modifier revealVote(bool vote, string memory secret) {
        // Manipulate time to pass the committing time
        vm.warp(block.timestamp + COMMITTING_TIME);

        // Reveal vote
        vm.prank(USER1);
        dao.revealDisputeVote(0, vote, secret);
        _;
    }

    modifier createUpgradeProposal() {
        // Deploy new shop
        FP_Shop newShop = new FP_Shop();

        vm.prank(USER1);
        dao.newUpgradeProposal(address(newShop));
        _;
    }

    modifier spendReviewTime() {
        // Manipulate time to pass the review time
        FP_DAO.UpgradeProposal memory proposal = dao.queryUpgradeProposal(0);
        vm.warp(proposal.creationTimestamp + PROPOSAL_REVIEW_TIME + 1);
        _;
    }
    
    modifier spendVotingTime() {
        // Manipulate time to pass the review time
        FP_DAO.UpgradeProposal memory proposal = dao.queryUpgradeProposal(0);
        vm.warp(proposal.creationTimestamp + PROPOSAL_VOTING_TIME + 1);
        _;
    }

    modifier mintAndVoteOnProposal(address user, uint256 amount, bool vote) {
        // Mint FP_tokens
        vm.prank(vm.envAddress("DEPLOYER"));
        token.mint(user, amount);
        assertEq(token.balanceOf(user), amount, "Wrong balance");
        
        // Cast vote
        vm.prank(user);
        dao.castVoteOnProposal(0, vote);
        _;
    }

    modifier cast501Votes(bool vote) {        
        // Mint FP_tokens and cast enough votes to pass the proposal (proposalQuorum = 500)
        for (uint160 i = 1; i <= 501; i++){
            // Mint FP_tokens
            vm.prank(vm.envAddress("DEPLOYER"));
            token.mint(address(i), 1000);
            assertEq(token.balanceOf(address(i)), 1000, "Wrong balance");
            
            // Cast vote
            vm.prank(address(i));
            dao.castVoteOnProposal(0, vote);
        }
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(SELLER1, 10 ether);
        vm.deal(BUYER1, 10 ether);
        vm.deal(USER1, 10 ether);
        vm.deal(USER2, 10 ether);

        DeployFaillapop deploy = new DeployFaillapop();
        (shop, token, coolNFT, powersellerNFT, dao, vault, proxy) = deploy.run();
    }

    /************************************** Tests **************************************/

    function test_setShop() public view {
        assertTrue(dao.hasRole(bytes32(dao.CONTROL_ROLE()), address(proxy)));
        assertEq(address(dao.shopAddress()), address(proxy));
    }   

    function test_setShop_x2() public {
        vm.prank(address(proxy));
        vm.expectRevert(bytes("Shop address already set"));
        dao.setShop(address(proxy));
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
        assertEq(disputeBefore.committingStartingTime, 0, "Wrong committingStartingTime");
        assertEq(disputeBefore.revealingStartingTime, 0, "Wrong revealingStartingTime");
        assertEq(uint256(disputeBefore.state), uint256(IFP_DAO.DisputeState.NOT_ACTIVE), "Wrong totalVoters");

        // Create dispute
        vm.prank(SELLER1);
        (bool success,) = address(proxy).call(
                abi.encodeWithSignature(
                    "disputedSaleReply(uint256,string)",
                    0,
                    "Seller's reasoning" 
                )
            );
        require(success, "Disputed sale not replied");

        // Check the dispute creation
        FP_DAO.Dispute memory disputeAfter = dao.queryDispute(0);
        assertEq(disputeAfter.itemId, 0, "Wrong itemId, dispute creation failed");
        assertEq(disputeAfter.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning, dispute creation failed");
        assertEq(disputeAfter.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning, dispute creation failed");
        assertEq(disputeAfter.votesFor, 0, "Wrong votesFor, dispute creation failed");
        assertEq(disputeAfter.votesAgainst, 0, "Wrong votesAgainst, dispute creation failed");
        assertEq(disputeAfter.totalVoters, 0, "Wrong totalVoters, dispute creation failed");
        assertEq(disputeAfter.committingStartingTime, block.timestamp, "Wrong committingStartingTime");
        assertEq(disputeAfter.revealingStartingTime, 0, "Wrong revealingStartingTime");
        assertEq(uint256(disputeAfter.state), uint256(IFP_DAO.DisputeState.COMMITTING_PHASE), "Wrong totalVoters");
    }

    function test_newDispute_RevertIf_CallerIsNotTheShop() public createLegitSale() buyLastItem() disputeSale() {
        // Create dispute with unauthorized account
        vm.prank(SELLER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(SELLER1), keccak256("CONTROL_ROLE")));
        dao.newDispute(0, "Buyer's reasoning", "Seller's reasoning");
    }

    
    function test_commitVoteOnDispute() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {
        // Check 
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        assertEq(uint(dao.hasVotedOnDispute(USER1, 0)), uint(IFP_DAO.Vote.COMMITTED), "Wrong hasVoted");
        assertEq(uint(dao.commitsOnDisputes(0, USER1)), uint(keccak256(abi.encodePacked(true, "secret"))),"Wrong commit");        
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
        assertEq(dispute.revealingStartingTime, 0, "Wrong revealingStartingTime");
        assertEq(uint256(dispute.state), uint256(IFP_DAO.DisputeState.COMMITTING_PHASE), "Wrong state");
    }

    function test_commitVoteOnDispute_RevertIf_NotInCommitingPhase() public createLegitSale() buyLastItem() {
        // Commit vote
        bytes32 commit = keccak256(abi.encodePacked(true, "secret"));
        vm.prank(USER1);
        vm.expectRevert(bytes("Dispute is not in committing phase"));
        dao.commitVoteOnDispute(0, commit);
    }

    function test_commitVoteOnDispute_RevertIf_UserHasAlreadyVoted() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {        
        // Commit vote again
        vm.expectRevert(bytes("You have already voted"));
        vm.prank(USER1);
        dao.commitVoteOnDispute(0, keccak256(abi.encodePacked(true, "secret")));
    }

    function test_revealDisputeVote() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") revealVote(true, "secret") {
        // Check vote
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        assertEq(uint(dao.hasVotedOnDispute(USER1, 0)), uint(IFP_DAO.Vote.FOR), "Wrong hasVoted");
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 1000, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 1, "Wrong totalVoters");
        assertEq(dispute.revealingStartingTime, block.timestamp, "Wrong revealingStartingTime");
        assertEq(uint256(dispute.state), uint256(IFP_DAO.DisputeState.REVEALING_PHASE), "Wrong state");
    }

    function test_revealDisputeVote_RevertIf_ItsNeitherInReveilingPhaseNorInCommittingPhase() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Reveal vote
        vm.prank(USER1);
        vm.expectRevert(bytes("Conditions for advancing to revealing phase are not met"));
        dao.revealDisputeVote(0, true, "secret");
    }

    function test_revealDisputeVote_RevertIf_CommitingTimeHasNotElapsed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {
        // Reveal vote
        vm.prank(USER1);
        vm.expectRevert(bytes("Conditions for advancing to revealing phase are not met"));
        dao.revealDisputeVote(0, true, "secret");
    }

    function test_revealDisputeVote_RevertIf_UserHasNotCommitted() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {
        // Manipulate time to pass the committing time
        vm.warp(block.timestamp + COMMITTING_TIME);

        // Reveal vote
        vm.prank(USER2);
        vm.expectRevert(bytes("You currently have no vote to reveal"));
        dao.revealDisputeVote(0, true, "secret");
    }

    function test_revealDisputeVote_RevertIf_UserHasAlreadyRevealed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") revealVote(true, "secret") {
        // Reveal vote again
        vm.prank(USER1);
        vm.expectRevert(bytes("You currently have no vote to reveal"));
        dao.revealDisputeVote(0, true, "secret");
    }

    function test_revealDisputeVote_RevertIf_SecretIsWrong() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {
        // Manipulate time to pass the committing time
        vm.warp(block.timestamp + COMMITTING_TIME);

        // Reveal vote
        vm.prank(USER1);
        vm.expectRevert(bytes("Invalid vote hash"));
        dao.revealDisputeVote(0, true, "wrong secret");
    }

    function test_endDispute_VotesFor() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") revealVote(true, "secret") {
        vm.warp(block.timestamp + MIN_REVEALING_TIME);
        dao.endDispute(0);
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        IFP_DAO.Vote result = dao.queryDisputeResult(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
        assertEq(dispute.committingStartingTime, 0, "Wrong committingStartingTime");
        assertEq(dispute.revealingStartingTime, 0, "Wrong revealingStartingTime");
        assertEq(uint(result), uint(IFP_DAO.Vote.FOR), "Wrong result");
    }

    function test_endDispute_VotesAgainst() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(false, "secret") revealVote(false, "secret") {
        vm.warp(block.timestamp + MIN_REVEALING_TIME);
        dao.endDispute(0);
        FP_DAO.Dispute memory dispute = dao.queryDispute(0);
        IFP_DAO.Vote result = dao.queryDisputeResult(0);
        assertEq(dispute.itemId, 0, "Wrong itemId");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning");
        assertEq(dispute.votesFor, 0, "Wrong votesFor");
        assertEq(dispute.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(dispute.totalVoters, 0, "Wrong totalVoters");
        assertEq(dispute.committingStartingTime, 0, "Wrong committingStartingTime");
        assertEq(dispute.revealingStartingTime, 0, "Wrong revealingStartingTime");
        assertEq(uint(result), uint(IFP_DAO.Vote.AGAINST), "Wrong result");
    }

    function test_endDispute_RevertIf_NotInRevealingPhase() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {
        vm.expectRevert(bytes("Dispute is not in revealing phase"));
        dao.endDispute(0);
    }

    function test_endDispute_RevertIf_RevealingTimeHasNotElapsed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") revealVote(true, "secret") {
        vm.expectRevert(bytes("Minimum revealing time hasn't elapsed"));
        dao.endDispute(0);
    }

    function test_cancelDispute() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        vm.prank(address(proxy));
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

    function test_checkLottery() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") revealVote(true, "secret") {
        vm.warp(block.timestamp + MIN_REVEALING_TIME);
        dao.endDispute(0);
        
        vm.prank(USER1);
        dao.checkLottery(0);
        assertTrue(dao.hasCheckedLottery(USER1, 0));
    }

    function test_checkLottery_RevertIf_UserHasVotedToTheWrongSide() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") {
        uint amount2 = 130;
        vm.prank(vm.envAddress("DEPLOYER"));
        token.mint(address(USER2), amount2);
        
        bytes32 commit = keccak256(abi.encodePacked(false, "secret"));
        vm.prank(USER2);
        dao.commitVoteOnDispute(0, commit);

        vm.warp(block.timestamp + COMMITTING_TIME);
        vm.prank(USER1);
        dao.revealDisputeVote(0, true, "secret");
        vm.prank(USER2);
        dao.revealDisputeVote(0, false, "secret");

        vm.warp(block.timestamp + MIN_REVEALING_TIME);
        dao.endDispute(0);
        
        vm.expectRevert(bytes("User voted for the wrong side"));
        vm.prank(USER2);
        dao.checkLottery(0);
    }
    
    function test_checkLottery_RevertIf_UserHasAlreadyCheckedIt() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() mintAndCommitVote(true, "secret") revealVote(true, "secret") {
        vm.warp(block.timestamp + MIN_REVEALING_TIME);
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

    function test_newUpgradeProposal() public {
        // Save proposal before creation
        FP_DAO.UpgradeProposal memory proposalBefore = dao.queryUpgradeProposal(0);
        assertEq(proposalBefore.creator, address(0), "Wrong creator");
        assertEq(proposalBefore.id, 0, "Wrong proposalId");
        assertEq(proposalBefore.creationTimestamp, 0, "Wrong creation timestamp");
        assertEq(proposalBefore.approvalTimestamp, 0, "Wrong approval timestamp");
        assertEq(proposalBefore.newShop, address(0), "Wrong shop address");
        assertEq(proposalBefore.votesFor, 0, "Wrong votesFor");
        assertEq(proposalBefore.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(proposalBefore.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint256(proposalBefore.state), uint256(IFP_DAO.ProposalState.NOT_ACTIVE), "Wrong state");

        // Create proposal
        FP_Shop newShop = new FP_Shop();
        vm.prank(USER1);
        dao.newUpgradeProposal(address(newShop));

        // Check the dispute creation
        FP_DAO.UpgradeProposal memory newProposal = dao.queryUpgradeProposal(0);
        assertEq(newProposal.creator, USER1, "Wrong creator");
        assertEq(newProposal.id, 0, "Wrong proposalId");
        assertEq(newProposal.creationTimestamp, block.timestamp, "Wrong creation timestamp");
        assertEq(newProposal.approvalTimestamp, 0, "Wrong approval timestamp");
        assertEq(newProposal.newShop, address(newShop), "Wrong shop address");
        assertEq(newProposal.votesFor, 0, "Wrong votesFor");
        assertEq(newProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(newProposal.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint256(newProposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_newUpgradeProposal_RevertIf_AddressHasNoCode() public {
        vm.prank(USER1);
        vm.expectRevert(bytes("The new shop address is invalid"));
        dao.newUpgradeProposal(address(3333));
    }

    function test_castVoteOnProposal_VoteFor() public createUpgradeProposal() spendReviewTime() mintAndVoteOnProposal(USER1, 1000, true) {        
        // Check vote
        FP_DAO.UpgradeProposal memory updatedProposal = dao.queryUpgradeProposal(0);
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER1), 0)), uint(IFP_DAO.Vote.FOR),"Wrong hasVoted");
        assertEq(updatedProposal.id, 0, "Wrong proposalId");
        assertEq(updatedProposal.votesFor, 1000, "Wrong votesFor");
        assertEq(updatedProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(updatedProposal.totalVoters, 1, "Wrong totalVoters");        
        assertEq(uint256(updatedProposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_castVoteOnProposal_VoteAgainst() public createUpgradeProposal() spendReviewTime() mintAndVoteOnProposal(USER1, 1000, false) {
        // Check vote
        FP_DAO.UpgradeProposal memory updatedProposal = dao.queryUpgradeProposal(0);
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER1), 0)), uint(IFP_DAO.Vote.AGAINST),"Wrong hasVoted");
        assertEq(updatedProposal.id, 0, "Wrong proposalId");
        assertEq(updatedProposal.votesFor, 0, "Wrong votesFor");
        assertEq(updatedProposal.votesAgainst, 1000, "Wrong votesAgainst");
        assertEq(updatedProposal.totalVoters, 1, "Wrong totalVoters");
        assertEq(uint256(updatedProposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_castVoteOnProposal_2Votes() public createUpgradeProposal() spendReviewTime() mintAndVoteOnProposal(USER1, 1000, false) mintAndVoteOnProposal(USER2, 3500, true){       
        // Check vote
        FP_DAO.UpgradeProposal memory updatedProposal = dao.queryUpgradeProposal(0);
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER1), 0)), uint(IFP_DAO.Vote.AGAINST),"Wrong hasVoted");
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER2), 0)), uint(IFP_DAO.Vote.FOR),"Wrong hasVoted");
        assertEq(updatedProposal.id, 0, "Wrong proposalId");
        assertEq(updatedProposal.votesAgainst, 1000, "Wrong votesAgainst");
        assertEq(updatedProposal.votesFor, 3500, "Wrong votesFor");
        assertEq(updatedProposal.totalVoters, 2, "Wrong totalVoters");
        assertEq(uint256(updatedProposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_castVoteOnProposal_RevertIf_ReviewTimeHasNotElapsed() public createUpgradeProposal() {
        // Mint FP_tokens
        uint amount = 1000;
        vm.prank(vm.envAddress("DEPLOYER"));
        token.mint(address(USER1), amount);
        assertEq(token.balanceOf(address(USER1)), amount, "Wrong balance");
        
        // Cast vote
        vm.prank(USER1);
        vm.expectRevert(bytes("Proposal is not ready to be voted"));
        dao.castVoteOnProposal(0, true);

        // Check vote
        FP_DAO.UpgradeProposal memory proposal = dao.queryUpgradeProposal(0);
        
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER1), 0)), uint(IFP_DAO.Vote.DIDNT_VOTE),"Wrong hasVoted");
        assertEq(proposal.votesFor, 0, "Wrong votesFor");
        assertEq(proposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(proposal.totalVoters, 0, "Wrong totalVoters");
    }

    function test_castVoteOnProposal_RevertIf_ProposalIsNotActive() public {
        // Mint FP_tokens
        uint amount = 1000;
        vm.prank(vm.envAddress("DEPLOYER"));
        token.mint(address(USER1), amount);
        assertEq(token.balanceOf(address(USER1)), amount, "Wrong balance");
        
        // Cast vote
        vm.prank(USER1);
        vm.expectRevert(bytes("Proposal is not active"));
        dao.castVoteOnProposal(0, true);
    }

    function test_castVoteOnProposal_RevertIf_UserHasAlreadyVoted() public createUpgradeProposal() spendReviewTime() mintAndVoteOnProposal(USER1, 1000, true){
        // Cast another vote
        vm.prank(USER1);
        vm.expectRevert(bytes("You have already voted"));
        dao.castVoteOnProposal(0, true);

        // Check vote
        FP_DAO.UpgradeProposal memory updatedProposal = dao.queryUpgradeProposal(0);
        
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER1), 0)), uint(IFP_DAO.Vote.FOR),"Wrong hasVoted");
        assertEq(updatedProposal.id, 0, "Wrong proposalId");
        assertEq(updatedProposal.votesFor, 1000, "Wrong votesFor");
        assertEq(updatedProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(updatedProposal.totalVoters, 1, "Wrong totalVoters");
        assertEq(uint256(updatedProposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_castVoteOnProposal_RevertIf_HasNoTokens() public createUpgradeProposal() spendReviewTime() {    
        // Cast vote
        vm.prank(USER1);
        vm.expectRevert(bytes("You have no voting power"));
        dao.castVoteOnProposal(0, true);

        // Check vote
        FP_DAO.UpgradeProposal memory updatedProposal = dao.queryUpgradeProposal(0);
        
        assertEq(uint(dao.hasVotedOnUpgradeProposal(address(USER1), 0)), uint(IFP_DAO.Vote.DIDNT_VOTE),"Wrong hasVoted");
        assertEq(updatedProposal.votesFor, 0, "Wrong votesFor");
        assertEq(updatedProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(updatedProposal.totalVoters, 0, "Wrong totalVoters");
    }

    function test_cancelProposalByCreator() public createUpgradeProposal() {
        // Cancel proposal
        vm.prank(USER1);
        dao.cancelProposalByCreator(0);

        // Check proposal
        FP_DAO.UpgradeProposal memory canceledProposal = dao.queryUpgradeProposal(0);
        assertEq(canceledProposal.creator, address(0), "Wrong creator");
        assertEq(canceledProposal.id, 0, "Wrong proposalId");
        assertEq(canceledProposal.creationTimestamp, 0, "Wrong timestamp");
        assertEq(canceledProposal.approvalTimestamp, 0, "Wrong timestamp");
        assertEq(canceledProposal.newShop, address(0), "Wrong shop address");
        assertEq(canceledProposal.votesFor, 0, "Wrong votesFor");
        assertEq(canceledProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(canceledProposal.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint256(canceledProposal.state), uint256(IFP_DAO.ProposalState.NOT_ACTIVE), "Wrong state");
    }

    function test_cancelProposalByCreator_RevertIf_CallerIsNotCreator() public createUpgradeProposal() {
        // Cancel proposal
        vm.prank(USER2);
        vm.expectRevert(bytes("You are not the creator of the proposal"));
        dao.cancelProposalByCreator(0);

        // Check proposal
        FP_DAO.UpgradeProposal memory proposal = dao.queryUpgradeProposal(0);
        assertEq(proposal.creator, USER1, "Wrong creator");
        assertEq(proposal.id, 0, "Wrong proposalId");
        assertEq(proposal.creationTimestamp, block.timestamp, "Wrong timestamp");
        assertEq(uint256(proposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_cancelProposalByCreator_RevertIf_ProposalIsNotActive() public {
        // Cancel proposal 
        vm.prank(USER1);
        vm.expectRevert(bytes("Proposal is not active"));
        dao.cancelProposalByCreator(0);
    }

    function test_cancelProposal() public createUpgradeProposal() {
        // Cancel proposal 
        vm.prank(USER2);
        dao.cancelProposal(0, "password");

        FP_DAO.UpgradeProposal memory canceledProposal = dao.queryUpgradeProposal(0);
        assertEq(canceledProposal.creator, address(0), "Wrong creator");
        assertEq(canceledProposal.id, 0, "Wrong proposalId");
        assertEq(canceledProposal.creationTimestamp, 0, "Wrong timestamp");
        assertEq(canceledProposal.newShop, address(0), "Wrong shop address");
        assertEq(canceledProposal.votesFor, 0, "Wrong votesFor");
        assertEq(canceledProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(canceledProposal.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint256(canceledProposal.state), uint256(IFP_DAO.ProposalState.NOT_ACTIVE), "Wrong state");
    }

    function test_cancelProposal_RevertIf_PasswordIsWrong() public createUpgradeProposal() {
        // Cancel proposal 
        vm.prank(USER2);
        vm.expectRevert(bytes("Unauthorized"));
        dao.cancelProposal(0, "qwerty");

        // Check proposal
        FP_DAO.UpgradeProposal memory proposal = dao.queryUpgradeProposal(0);
        assertEq(proposal.creator, USER1, "Wrong creator");
        assertEq(proposal.id, 0, "Wrong proposalId");
        assertEq(proposal.creationTimestamp, block.timestamp, "Wrong timestamp");
        assertEq(uint256(proposal.state), uint256(IFP_DAO.ProposalState.ACTIVE), "Wrong state");
    }

    function test_cancelProposal_RevertIf_ProposalIsNotActive() public {
        // Cancel proposal 
        vm.prank(USER1);
        vm.expectRevert(bytes("Proposal is not active"));
        dao.cancelProposal(0, "password");
    }

    function test_resolveUpgradeProposal_Approved() public createUpgradeProposal() spendReviewTime() cast501Votes(true) spendVotingTime() {
        // Check current shop implementation and obtain new shop address
        assertEq(proxy.getImplementation(), address(shop), "Actual implementation is wrong");
        FP_DAO.UpgradeProposal memory proposalBefore = dao.queryUpgradeProposal(0);

        // Resolve proposal
        dao.resolveUpgradeProposal(0);

        // Check proposal
        FP_DAO.UpgradeProposal memory resolvedProposal = dao.queryUpgradeProposal(0);
        assertEq(resolvedProposal.creator, proposalBefore.creator, "Wrong creator");
        assertEq(resolvedProposal.id, 0, "Wrong proposalId");
        assertEq(resolvedProposal.creationTimestamp, proposalBefore.creationTimestamp, "Wrong timestamp");
        assertEq(resolvedProposal.approvalTimestamp, block.timestamp, "Wrong timestamp");
        assertEq(resolvedProposal.newShop, proposalBefore.newShop, "Wrong shop address");
        assertEq(resolvedProposal.votesFor, proposalBefore.votesFor, "Wrong votesFor");
        assertEq(resolvedProposal.votesAgainst, proposalBefore.votesAgainst, "Wrong votesAgainst");
        assertEq(resolvedProposal.totalVoters, proposalBefore.totalVoters, "Wrong totalVoters");
        assertEq(uint256(resolvedProposal.state), uint256(IFP_DAO.ProposalState.PASSED), "Wrong state");

        // Check proposal result
        assertEq(uint(dao.queryUpgradeProposalResult(0)), uint(IFP_DAO.Vote.FOR), "Wrong proposal result");

        // Check current implementation again
        assertEq(proxy.getImplementation(), address(shop), "Actual implementation is wrong");
    }

    function test_resolveUpgradeProposal_NotApproved() public createUpgradeProposal() spendReviewTime() cast501Votes(false) spendVotingTime() {
        // Check current shop implementation and obtain new shop address
        assertEq(proxy.getImplementation(), address(shop), "Actual implementation is wrong");

        // Resolve proposal
        dao.resolveUpgradeProposal(0);

        // Check proposal
        FP_DAO.UpgradeProposal memory resolvedProposal = dao.queryUpgradeProposal(0);
        assertEq(resolvedProposal.creator, address(0), "Wrong creator");
        assertEq(resolvedProposal.id, 0, "Wrong proposalId");
        assertEq(resolvedProposal.creationTimestamp, 0, "Wrong timestamp");
        assertEq(resolvedProposal.approvalTimestamp, 0, "Wrong timestamp");
        assertEq(resolvedProposal.newShop, address(0), "Wrong shop address");
        assertEq(resolvedProposal.votesFor, 0, "Wrong votesFor");
        assertEq(resolvedProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(resolvedProposal.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint256(resolvedProposal.state), uint256(IFP_DAO.ProposalState.NOT_ACTIVE), "Wrong state");

        // Check proposal result
        assertEq(uint(dao.queryUpgradeProposalResult(0)), uint(IFP_DAO.Vote.AGAINST), "Wrong proposal result");

        // Check current implementation
        assertEq(proxy.getImplementation(), address(shop), "Actual implementation is wrong");
    }

    function test_resolveUpgradeProposal_RevertIf_ProposalIsNotActive() public {
        // Resolve proposal
        vm.expectRevert(bytes("Proposal is not active"));
        dao.resolveUpgradeProposal(0);
    }

    function test_resolveUpgradeProposal_RevertIf_VotingTimeHasNotElapsed() public createUpgradeProposal() spendReviewTime() mintAndVoteOnProposal(USER1, 1000, false) {
        // Resolve proposal
        vm.expectRevert(bytes("Proposal is not ready to be resolved"));
        dao.resolveUpgradeProposal(0);
    }
    
    function test_resolveUpgradeProposal_RevertIf__NotEnoughUsersVoted() public createUpgradeProposal() spendReviewTime() mintAndVoteOnProposal(USER1, 1000, false) spendVotingTime() {
        // Resolve proposal
        vm.expectRevert(bytes("Not enough voters"));
        dao.resolveUpgradeProposal(0);
    }

    function test_executePassedProposal() public createUpgradeProposal() spendReviewTime() cast501Votes(true) spendVotingTime() {
        // Resolve proposal
        dao.resolveUpgradeProposal(0);
        
        // Check current shop implementation and obtain new shop address
        assertEq(proxy.getImplementation(), address(shop), "Actual implementation is wrong");
        FP_DAO.UpgradeProposal memory proposalBefore = dao.queryUpgradeProposal(0);
        address newShop = proposalBefore.newShop;

        // Execute proposal
        vm.warp(block.timestamp + PROPOSAL_EXECUTION_DELAY + 1);
        dao.executePassedProposal(0);

        // Check proposal
        FP_DAO.UpgradeProposal memory executedProposal = dao.queryUpgradeProposal(0);
        assertEq(executedProposal.creator, address(0), "Wrong creator");
        assertEq(executedProposal.id, 0, "Wrong proposalId");
        assertEq(executedProposal.creationTimestamp, 0, "Wrong timestamp");
        assertEq(executedProposal.approvalTimestamp, 0, "Wrong timestamp");
        assertEq(executedProposal.newShop, address(0), "Wrong shop address");
        assertEq(executedProposal.votesFor, 0, "Wrong votesFor");
        assertEq(executedProposal.votesAgainst, 0, "Wrong votesAgainst");
        assertEq(executedProposal.totalVoters, 0, "Wrong totalVoters");
        assertEq(uint256(executedProposal.state), uint256(IFP_DAO.ProposalState.NOT_ACTIVE), "Wrong state");

        // Check new implementation again
        assertEq(proxy.getImplementation(), newShop, "Actual implementation is wrong");
    }

    function test_executePassedProposal_RevertIf_ProposalIsNotPassed() public createUpgradeProposal() spendReviewTime() cast501Votes(true) spendVotingTime() {
        // Execute proposal
        vm.expectRevert(bytes("Proposal is not passed"));
        dao.executePassedProposal(0);
    }

    function test_executePassedProposal_RevertIf_DelayHasNotElapsed() public createUpgradeProposal() spendReviewTime() cast501Votes(true) spendVotingTime() {
        // Resolve proposal
        dao.resolveUpgradeProposal(0);

        // Execute proposal
        vm.expectRevert(bytes("Proposal is not ready to be executed"));
        dao.executePassedProposal(0);
    }
}