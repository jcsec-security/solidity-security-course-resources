// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IFP_DAO.sol";
import "./interfaces/IFP_Vault.sol";

/** 
    @title The FaillaPop Shop! [v.02]
    @author Faillapop team :D 
    @notice The contract allows anyone to sell and buy goods in a decentralized manner! The seller has to lock funds to avoid malicious behaviour.
        In addition, unhappy buyers can open a claim and the DAO will decide if the seller misbehaved or not.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract FP_Shop is AccessControl {

    /************************************** Constants *******************************************************/
    ///@notice The admin role ID for the AccessControl contract
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    ///@notice The DAO role ID for the AccessControl contract
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    ///@notice The blacklisted role ID for the AccessControl contract
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");


    /************************************** State vars  and Structs *******************************************************/
    /**
        @dev A Sale can be in one of three states: 
        `Selling` deal still active
        `Disputed` the buyer submitted a claim
        `Pending` waiting buyer confirmation
        `Sold` deal is over, no claim was submitted
        `Vacation` the seller is on vacation, sale halted
    */
    enum State {
        Selling,
        Pending,
        Disputed,
        Sold,
        Vacation
    }


    /**
        @dev A Sale struct represent each of the active sales in the shop.
        @param seller The address of the seller
        @param buyer The address of the buyer, if any
        @param title The title of the item being sold
        @param description A description of the item being sold
        @param price The price in Ether of the item being sold
        @param state The current state of the sale
     */
    struct Sale {
        address seller;
        address buyer;
        string title;
        string description; 
        uint price;
        State state;
    }  


    /**
        @dev A Dispute struct represent each of the active disputes in the shop.
        @param itemId The ID of the item being disputed
        @param buyerReasoning The reasoning of the buyer for the claim
        @param sellerReasoning The reasoning of the seller against the claim
     */
    struct Dispute {
        uint256 disputeId;
        string buyerReasoning;
        string sellerReasoning;
    }  


    ///@notice Mapping between the item ID and its Sale struct
    mapping (uint256 => Sale) public offered_items;
    ///@notice The index of the next new Sale
    uint256 public  offerIndex;
    ///@notice Mapping between the itemId the Shop's dispute struct
    mapping (uint256 => Dispute) public disputed_items;
    ///@notice The list of blacklisted seller addresses
    address[] public blacklistedSellers;
    ///@notice Faillapop vault contract
    IFP_Vault public vaultContract;
    ///@notice Faillapop DAO contract
    IFP_DAO public daoContract;


    /************************************** Events and modifiers *****************************************************/

    ///@notice Emitted when a user buys an item, contains the user address and the item ID
    event Buy(address user, uint item);
    ///@notice Emitted when a user creates a new sale, contains the item ID and the title of the item
    event NewItem(uint id, string title);
    ///@notice Emitted when a user modifies a sale, contains the item ID and the title of the item
    event ModifyItem(uint id, string title);
    ///@notice Emitted when a user disputes a sale, contains the user address and the item ID
    event OpenDispute(address user, uint item);
    ///@notice Emitted when a user received a refund, contains the user address and the amount
    event Reimburse(address user, uint amount);
    ///@notice Emitted when a user receives an reward NFT, contains the user address
    event AwardNFT(address user);
    ///@notice Emitted when a user is blacklisted, contains the user address
    event BlacklistSeller(address seller);

    ///@notice Check if the caller is not blacklisted
    modifier notBlacklisted() {
        require(
            !hasRole(BLACKLISTED_ROLE, msg.sender),
            "Seller is blacklisted"
        );
        _;
    }


    /************************************** External  ****************************************************************/ 

    /**
        @notice Constructor of the contract
        @param dao_addr The address of the DAO contract
        @param vault_addr The address of the Vault contract
     */
    constructor(address dao_addr, address vault_addr) {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DAO_ROLE, dao_addr);

        daoContract = IFP_DAO(dao_addr);
        vaultContract = IFP_Vault(vault_addr);
    }


    /**
        @notice Endpoint to buy an item
        @param itemId The ID of the item being bought
        @dev The user must send the exact amount of Ether to buy the item
     */
    function doBuy(uint itemId) external payable {
        require(offered_items[itemId].seller != address(0), "itemId does not exist");
        require(offered_items[itemId].state == State.Selling, "Item cannot be bought");
        require(msg.value >= offered_items[itemId].price, "Incorrect amount of Ether sent");
        require(
            !hasRole(BLACKLISTED_ROLE, offered_items[itemId].seller),
            "Seller is blacklisted"
        );

        offered_items[itemId].buyer = msg.sender;
        offered_items[itemId].state = State.Pending;
        
        emit Buy(msg.sender, itemId);
    }
	

    /**
        @notice Endpoint to dispute a sale. The buyer will supply the supporting info to the DAO
        @param itemId The ID of the item being disputed
        @param buyerReasoning The reasoning of the buyer for the claim
     */
    function disputeSale(uint itemId, string calldata buyerReasoning) external {   
        require(offered_items[itemId].buyer == msg.sender, "Not the buyer");   

        offered_items[itemId].state = State.Disputed;

        // New dispute with ID = 0 until the correct one is set by the DAO
        Dispute memory newDispute = Dispute(0, buyerReasoning, "");
        disputed_items[itemId] = newDispute;
    }

    /**
        @notice Endpoint to confirm the receipt of an item and trigger the payment to the seller. 
        @param itemId The ID of the item being confirmed
     */
    function itemReceived(uint itemId) external {
        require(offered_items[itemId].buyer == msg.sender, "Not the buyer");
        offered_items[itemId].state = State.Sold;

        // Seller should be paid
        closeSale(itemId, true);
    }    


    /**
        @notice Endpoint to close a dispute. Both the DAO and the buyer could call this function to cancel a dispute
        @param itemId The ID of the item being disputed
     */
    function endDispute(uint256 itemId) external {
        require(offered_items[itemId].state == State.Disputed, "Dispute not found");

        if (msg.sender == offered_items[itemId].buyer) {
            // Self-cancelation of the dispute, the buyer accepts the item
            closeDispute(itemId);

        } else {
            // DAO resolving the dispute in favor of the seller, if the buyer wins `returnItem` will be called
            _checkRole(DAO_ROLE); // Will revert if msg.sender is doesn't have the DAO_ROLE
        }

        delete disputed_items[itemId];
        offered_items[itemId].state = State.Sold;

        // Seller should be paid
        closeSale(itemId, true);
}

    /**
        @notice Endpoint to create a new sale. The seller must have enough funds staked in the Vault so  
            price amount can be locked to desincentivice malicious behavior
        @param title The title of the item being sold
        @param description A description of the item being sold
        @param price The price in Ether of the item being sold
     */
    function newSale(string calldata title, string calldata description, uint256 price) external notBlacklisted() {
        require(price > 0, "Price must be greater than 0");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 currentId = offerIndex;
        Sale memory sale = Sale(msg.sender, address(0), title, description, price, State.Selling);
        offered_items[currentId] = sale; 

        // Lock seller staken funds to desincentivize malicious behavior
        vaultContract.doLock(msg.sender, price);

        offerIndex += 1;

        emit NewItem(currentId, title);
    }

    /**
        @notice Endpoint to modify an existing sale. Locked funds will be partially realeased if price decreases.
        @param itemId ID of the item being modified
        @param newTitle New title of the item being sold
        @param newDesc New description of the item being sold
        @param newPrice New price in Ether of the item being sold
     */
    function modifySale(uint256 itemId, string calldata newTitle, string calldata newDesc, uint256 newPrice) external {
        require(offered_items[itemId].seller == msg.sender, "Only the seller can modify the sale");   
        require(offered_items[itemId].state == State.Selling, "Sale can't be modified");	
        
        // Update vault
        uint priceDifference;
        if (offered_items[itemId].price > newPrice) {
            priceDifference = offered_items[itemId].price - newPrice;
            vaultContract.doUnlock(msg.sender, priceDifference);
        } else {
            priceDifference = newPrice - offered_items[itemId].price;
            vaultContract.doLock(msg.sender, priceDifference);
        }

        // Update details
        offered_items[itemId].title = newTitle;
        offered_items[itemId].description = newDesc;
        offered_items[itemId].price = newPrice;

        emit ModifyItem(itemId, newTitle);
    }


    /**
        @notice Endpoint to cancel an active sale
        @param itemId The ID of the item which sale is being cancelled
    */
    function cancelActiveSale (uint itemId) external { 
        require(offered_items[itemId].seller == msg.sender, "Only the seller can cancel the sale");   
        require(offered_items[itemId].state == State.Selling, "Sale can't be cancelled");     
        
        //Seller should NOT be paid
        closeSale(itemId, false);
    }    


    /**
        @notice Endpoint to set the vacation mode of a seller. If the seller is in vacation mode nobody can buy his goods
        @param _vacationMode The new vacation mode of the seller
     */
    function setVacationMode(bool _vacationMode) external {
        for (uint i = 0; i < offerIndex; i++) {
            if (offered_items[i].seller == msg.sender) {

                if (_vacationMode && offered_items[i].state == State.Selling) {
                    offered_items[i].state = State.Vacation;

                } else if (!_vacationMode && offered_items[i].state == State.Vacation) {
                    offered_items[i].state = State.Selling;

                }
            }
        }
    }


    /**
        @notice Endpoint to reply to a dispute. The seller will supply the supporting info to the DAO. If the seller does not reply,
            the admin could mark them as malicious and slash their funds
        @param itemId The ID of the item being disputed
        @param sellerReasoning The reasoning of the seller for the claim
     */
    function disputedSaleReply(uint itemId, string calldata sellerReasoning) external {    
        require(offered_items[itemId].seller == msg.sender, "Not the seller"); 
        require(offered_items[itemId].state == State.Disputed, "Item not disputed");  
    
        openDispute(itemId, sellerReasoning);
    }


    /** 
        @notice Endpoint to return an item, only the DAO can trigger it
        @param itemId The ID of the item being returned
     */
    function returnItem(uint256 itemId) external onlyRole(DAO_ROLE) {   
        require(offered_items[itemId].state == State.Disputed, "Item not disputed");

        /*
        * A future functionality for dealing with returns will be implemented here!
        */

        reimburse(itemId);
        closeSale(itemId, false);
    }

    /**
        @notice Endpoint to remove a malicious sale and slash the stake. The owner of the contract can remove a malicious sale and blacklist the seller
        @param itemId The ID of the item which sale is considered malicious
     */
    function removeMaliciousSale(uint itemId) external onlyRole(ADMIN_ROLE) {
        require(offered_items[itemId].seller != address(0), "itemId does not exist");

        if (offered_items[itemId].state == State.Pending) {
            reimburse(itemId);
        } else if (offered_items[itemId].state == State.Disputed) {
            reimburse(itemId);
            closeDispute(itemId);
        }

        // Seller should NOT be paid
        closeSale(itemId, false);
        blacklist(offered_items[itemId].seller); 
    }


    /************************************** Internal *****************************************************************/

    /**
        @notice Remove a sale from the list
        @param itemId The ID of the item which sale is being removed
        @param toBePaid If the seller should be paid or not
     */
    function closeSale(uint itemId, bool toBePaid) public {
        address seller = offered_items[itemId].seller;
        uint256 price = offered_items[itemId].price;

        // Seller payment
        if (toBePaid) {
            (bool success, ) = payable(seller).call{value: price}("");
            require(success, "Sale payment failed");
        }
        // Seller stake release
        vaultContract.doUnlock(seller, price);
        
        delete offered_items[itemId];
    }


    /**
        @notice Add a user to the seller blacklist and slash their funds in the Vault
        @param user The address of the seller
     */
    function blacklist(address user) internal {
        grantRole(BLACKLISTED_ROLE, user);
        //Slash the whole user stake
        vaultContract.doSlash(user);

        emit BlacklistSeller(user);
    }


    /**
        @notice Reimburse a buyer. 
        @param itemId The ID of the item being reimbursed
     */
    function reimburse(uint itemId) internal {
        uint price = offered_items[itemId].price; 	
        address buyer = offered_items[itemId].buyer;	

        // Pay the buyer back
        (bool success, ) = payable(buyer).call{value: price}("");
        require(success, "Sale payment failed");

        emit Reimburse(buyer, price);      
	}


    /** 
        @notice Open a dispute in the DAO contract
        @param itemId The ID of the item being disputed
        @param sellerReasoning The reasoning of the seller against the claim
     */
    function openDispute(uint itemId, string calldata sellerReasoning) internal {
        address buyer = offered_items[itemId].buyer;
        Dispute storage dispute = disputed_items[itemId]; 

        dispute.sellerReasoning = sellerReasoning;
        dispute.disputeId = daoContract.newDispute(
            itemId, 
            dispute.buyerReasoning, 
            dispute.sellerReasoning
        );
        // No need to "save" the above as dispute has been declared as storage

        emit OpenDispute(buyer, itemId);
    }

    /** 
        @notice Close a dispute in the DAO contract, either due to blacklisting or the buyer deciding not
            to pursue the dispute
        @param itemId The ID of the item being disputed
     */
    function closeDispute(uint itemId) internal {
        uint dId = disputed_items[itemId].disputeId;
        // Forcefully cancel an ongoing dispute
        daoContract.cancelDispute(dId);

        delete disputed_items[itemId];
    }

    /************************************** Views  *******************************************************/ 

    /**
        @notice View function to return the user's disputed sales
        @param itemId The ID of the item being disputed
        @return The dispute details
     */
	function query_dispute (uint itemId) public view returns (Dispute memory) {
		return disputed_items[itemId];
	}

    function query_sale (uint itemId) public view returns (Sale memory) {
        return offered_items[itemId];
    }

}