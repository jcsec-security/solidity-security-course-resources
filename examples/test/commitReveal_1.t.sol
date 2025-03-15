pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/102/3-CommitReveal_1.sol";

contract CRVotingTest is Test  {
    VotingContract public targetVoting;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address payable mallory = payable(address(0x4));
    uint256 proposalId;

    function setUp() public {
        //addresses
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(mallory, "Mallory");

        targetVoting = new VotingContract(200, 200);
        vm.label(address(targetVoting), "Voting_contract");

        proposalId = targetVoting.submitProposal("Proposal 1", "This is a test proposal");
 
    }

    function test_102_3_voting() public { //@todo replicate this on-chain without the reveal phase
        vm.warp(0);

        console.log("-- Are these hashes... actually secret? --");
        // Committing votes
        // commitHash should be of the format keccak256(abi.encodePacked(bool, msg.sender));
        bytes32 yesHashAlice = keccak256(abi.encodePacked(true, alice));
        vm.prank(alice);
        targetVoting.commitVote(proposalId, yesHashAlice);
        console.log("Alice voting hash is");
        console.logBytes32(yesHashAlice);

        bytes32 noHashBob = keccak256(abi.encodePacked(false, bob));
        vm.prank(bob);
        targetVoting.commitVote(proposalId, noHashBob);
        console.log("Bob voting hash is");
        console.logBytes32(noHashBob);

        bytes32 yesHashCarol = keccak256(abi.encodePacked(true, carol));
        vm.prank(carol);
        targetVoting.commitVote(proposalId, yesHashCarol);
        console.log("Carol voting hash is");
        console.logBytes32(yesHashCarol);        
        
        // Closing commit period
        vm.warp(202);

        // Revealing votes
        vm.prank(alice);
        targetVoting.revealVote(proposalId, true, alice);
        vm.prank(bob);
        targetVoting.revealVote(proposalId, false, bob);
        vm.prank(carol);
        targetVoting.revealVote(proposalId, true, carol);

        // Closing reveal period
        vm.warp(402);

        // Checking results
        ( , , uint256 votesFor, uint256 votesAgainst) = targetVoting.votingResults(proposalId);
        assertEq(votesFor, 2, "Incorrect voting results");
    }

}