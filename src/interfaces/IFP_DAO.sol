// SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.13;

/** 
    @title Iterface of the FaillaPop voting DAO for disputes
    @author Faillapop team :D 
    @notice The contract allow to vote with FPT tokens on open disputes. If the dispute is resolved in favor of the buyer,
    the seller have to refund the buyer. If the dispute is resolved in favor of the seller, the sale is closed.
    @custom:ctf This contract is of JC's mock-audit exercise at https://github.com/jcr-security/faillapop
*/
interface IFP_DAO {

    /************************************** Enums and structs  *****************************************************/

    /** 
        @notice The DisputeState enum is used to record the state of a dispute
        @dev NOT_ACTIVE is the default value, COMMITTING_PHASE is the state in which users are committing their secret vote, REVEALING_PHASE is the state in which users are revealing their vote
     */
    enum DisputeState {
        NOT_ACTIVE,
        COMMITTING_PHASE,
        REVEALING_PHASE
    }

    /** 
        @notice The ProposalState enum is used to record the state of a proposal
        @dev NOT_ACTIVE is the default value, ACTIVE is the state of an existing proposal, PASSED is the state of a proposal that has been voted and passed but not yet executed
     */
    enum ProposalState {
        NOT_ACTIVE,
        ACTIVE,
        PASSED
    }

    /**
        @notice The Vote enum is used to record the vote of a user
        @dev DIDNT_VOTE is the default value, COMMITTED is the first phase, FOR and AGAINST are the possible votes
     */
    enum Vote {
        DIDNT_VOTE,
        COMMITTED,
        FOR,
        AGAINST
    }
    
    /** 
        @notice A Dispute includes the itemId, the reasoning of the buyer and the seller on the claim,
        and the number of votes for and against the dispute.
        @dev A Dispute is always written from the POV of the buyer
            - FOR is in favor of the buyer claim
            - AGAINST is in favor of the seller claim
     */
    struct Dispute {
        uint256 itemId;
        string buyerReasoning;
        string sellerReasoning;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVoters;
        uint256 committingStartingTime;
        uint256 revealingStartingTime;
        DisputeState state;
    }

    /** 
        @notice An UpgradeProposal includes the address of the creator, the id, the creationTimestamp, the new contract address, 
        the number of votes for and against the proposal, the total number of voters and the status of the proposal.
        @dev newShop is the address of the new contract which can be checked on etherscan
     */
    struct UpgradeProposal {
        address creator;
        uint256 id;
        uint256 creationTimestamp;
        uint256 approvalTimestamp;
        address newShop;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVoters;
        ProposalState state;
    }

    /************************************** Events  *****************************************************/

    ///@notice Emitted when the contract configuration is changed, contains the address of the Shop
    event NewConfig(address shop, address nft);
    ///@notice Emitted when a user commits the hash of his vote, contains the disputeId and the user address 
    event DisputeVoteCommitted(uint disputeId, address user);
    ///@notice Emitted when a user votes, contains the disputeId and the user address
    event DisputeVoteCasted(uint256 disputeId, address user);
    ///@notice Emitted when a new dispute is created, contains the disputeId and the itemId
    event NewDispute(uint256 disputeId, uint256 itemId);
    ///@notice Emitted when a dispute is closed, contains the disputeId and the itemId
    event EndDispute(uint256 disputeId, uint256 itemId);
    ///@notice Emitted when a user is awarder a cool NFT, contains the user address
    event AwardNFT(address user);

    ///@notice Emitted when a new upgrade proposal is created, contains the proposalId, the creationTimestamp and the new contract address
    event NewUpgradeProposal(uint256 id, uint256 creationTimestamp, address newShop);
    ///@notice Emitted when a user votes on an upgrade proposal, contains the proposalId and the user address
    event ProposalVoteCasted(uint256 proposalId, address user);
    ///@notice Emitted when an upgrade proposal is passed, contains the proposalId, the new contract address and the timestamp
    event ProposalPassed(uint256 proposalId, address newShop, uint256 approvalTimestamp);
    ///@notice Emitted when an upgrade proposal is not passed because not enough users voted in favor, contains the proposalId and the new contract address 
    event ProposalNotPassed(uint256 proposalId, address newShop);
    ///@notice Emitted when an upgrade proposal is executed, contains the proposalId and the new contract address
    event ProposalExecuted(uint256 proposalId, address newShop);
    ///@notice Emitted when an upgrade proposal is canceled, contains the proposalId
    event ProposalCanceled(uint256 proposalId);


    /************************************** Functions *****************************************************/

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