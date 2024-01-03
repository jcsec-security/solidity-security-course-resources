// SPDX-License-Identifier: GPL-3.0 

pragma solidity ^0.8.13;


/** 
    @title Interface of the FaillaPop Shop!
    @author Faillapop team :D 
    @notice The contract allows anyone to stake and unstake Ether. When a seller publish a new item
    in the shop, the funds are locked during the sale. If the user is considered malicious
    by the DAO, the funds are slashed. 
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
interface IFP_Shop {
    /**
        @notice Endpoint to buy an item
        @param itemId The ID of the item being bought
        @dev The user must send the exact amount of Ether to buy the item
     */
    function doBuy(uint256 itemId) external payable;
	
    /**
        @notice Endpoint to dispute a sale. The buyer will supply the supporting info to the DAO
        @param itemId The ID of the item being disputed
        @param buyerReasoning The reasoning of the buyer for the claim
     */
    function disputeSale(uint256 itemId, string calldata buyerReasoning) external;

    /**
        @notice Endpoint to confirm the receipt of an item and trigger the payment to the seller. 
        @param itemId The ID of the item being confirmed
     */
    function itemReceived(uint256 itemId) external;


    /**
        @notice Endpoint to close a dispute. Both the DAO and the buyer could call this function to cancel a dispute
        @param itemId The ID of the item being disputed
     */
    function endDispute(uint256 itemId) external;

    /**
        @notice Endpoint to create a new sale. The seller must have enough funds staked in the Vault so  
            price amount can be locked to desincentivice malicious behavior
        @param title The title of the item being sold
        @param description A description of the item being sold
        @param price The price in Ether of the item being sold
     */
    function newSale(string calldata title, string calldata description, uint256 price) external;

    /**
        @notice Endpoint to modify an existing sale. Locked funds will be partially realeased if price decreases.
        @param itemId ID of the item being modified
        @param newTitle New title of the item being sold
        @param newDesc New description of the item being sold
        @param newPrice New price in Ether of the item being sold
     */
    function modifySale(uint256 itemId, string calldata newTitle, string calldata newDesc, uint256 newPrice) external;

    /**
        @notice Endpoint to cancel an active sale
        @param itemId The ID of the item which sale is being cancelled
    */
    function cancelActiveSale (uint256 itemId) external;

    /**
        @notice Endpoint to set the vacation mode of a seller. If the seller is in vacation mode nobody can buy his goods
        @param vacationMode The new vacation mode of the seller
     */
    function setVacationMode(bool vacationMode) external;


    /**
        @notice Endpoint to reply to a dispute. The seller will supply the supporting info to the DAO. If the seller does not reply,
            the admin could mark them as malicious and slash their funds
        @param itemId The ID of the item being disputed
        @param sellerReasoning The reasoning of the seller for the claim
     */
    function disputedSaleReply(uint256 itemId, string calldata sellerReasoning) external;


    /** 
        @notice Endpoint to return an item, only the DAO can trigger it
        @param itemId The ID of the item being returned
     */
    function returnItem(uint256 itemId) external;

    /**
        @notice Endpoint to remove a malicious sale and slash the stake. The owner of the contract can remove a malicious sale and blacklist the seller
        @param itemId The ID of the item which sale is considered malicious
     */
    function removeMaliciousSale(uint256 itemId) external;

}