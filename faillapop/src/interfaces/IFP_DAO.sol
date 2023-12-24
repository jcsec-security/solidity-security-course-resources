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
        @notice Update the contract's configuration details
        @param magicWord to authenticate as privileged user
        @param newMagicWord The new password to access key features
     */
    function updateConfig(
        string calldata magicWord, 
        string calldata newMagicWord, 
        address newShop
    ) external;

    /**
        @notice Cast a vote on a dispute
        @param disputeId The ID of the target dispute
     */
    function castVote(uint256 disputeId) external;

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
        @notice Resolve a finished dispute
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
}