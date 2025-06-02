// SPDX-License-Identifier: GPL-3.0 

pragma solidity ^0.8.13;

/** 
    @title Iterface of the FaillaPop voting DAO for disputes
    @author Faillapop team :D 
    @notice The contract allow to vote with FPT tokens on open disputes. If the dispute is resolved in favor of the buyer,
    the seller have to refund the buyer. If the dispute is resolved in favor of the seller, the sale is closed.
    @custom:ctf This contract is of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
interface IFP_DAO {

    /**
        @notice Sets the shop address as the new Control role
        @param shop The address of the shop 
    */
    function setShop(address shop) external;

    /**
        @notice Commit the hash of the vote
        @param disputeId The ID of the target dispute
        @param commit Vote + secret hash
     */
    function commitVoteOnDispute(uint256 disputeId, bytes32 commit) external;

    /**
        @notice Open a dispute
        @param itemId The ID of the item involved in the dispute
        @param buyerReasoning The reasoning of the buyer in favor of the claim
        @param sellerReasoning The reasoning of the seller against the claim
     */
    function newDispute( 
        uint256 itemId, 
        string calldata buyerReasoning, 
        string calldata sellerReasoning
    ) external returns (uint256);

    /**
        @notice Reveal a vote on a dispute if enough users have voted
        @param disputeId The ID of the target dispute
        @param vote The vote of the user
        @param secret The secret used to commit the vote
     */
    function revealDisputeVote(uint disputeId, bool vote, string calldata secret) external;

    /**
        @notice Resolve a dispute if revealing time has elapsed and remove it from the storage
        @param disputeId The ID of the target dispute
     */
    function endDispute(uint256 disputeId) external;


    /**
        @notice Cancel an ongoing dispute. Either by the buyer or blacklisting (shop contract)
        @param disputeId The ID of the target dispute
     */
    function cancelDispute(uint256 disputeId) external;

    
    /**
        @notice Award NFT to a user if they voten for the winning side
        @param disputeID The ID of the target dispute
     */
    function checkLottery(uint256 disputeID) external;

    /**
        @notice Open an upgrade proposal
        @param addrNewShop The address of the new Shop contract proposed
     */
    function newUpgradeProposal(address addrNewShop) external returns (uint);

    /**
        @notice Cast a vote on an upgrade proposal
        @param proposalId The ID of the upgrade proposal
        @param vote The vote, true for FOR, false for AGAINST
     */
    function castVoteOnProposal(uint proposalId, bool vote) external;

    /**
        @notice Cancel an ongoing upgrade proposal by the proposal creator
        @param proposalId The ID of the upgrade proposal
     */
    function cancelProposalByCreator(uint proposalId) external;

    /**
        @notice Cancel an ongoing upgrade proposal by the admin of the DAO (who knows the password)
        @param proposalId The ID of the upgrade proposal
        @param magicWord The password to access key features
     */
    function cancelProposal(uint proposalId, string calldata magicWord) external;

    /**
        @notice Resolve a proposal if enough users have voted and enough time has passed
        @param proposalId The ID of the upgrade proposal
     */
    function resolveUpgradeProposal(uint256 proposalId) external;

    /**
        @notice Execute a passed proposal
        @param proposalId The ID of the upgrade proposal
     */
    function executePassedProposal(uint256 proposalId) external;

}