// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IFP_DAO} from "./interfaces/IFP_DAO.sol";
import {IFP_Shop} from "./interfaces/IFP_Shop.sol";
import {IFP_Vault} from "./interfaces/IFP_Vault.sol";
import {IFP_PowersellerNFT} from "./interfaces/IFP_PowersellerNFT.sol";
import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts@v5.0.1/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts@v5.0.1/proxy/utils/Initializable.sol";

/** 
    @title The FaillaPop Shop! [v.02]
    @author Faillapop team :D 
    @notice The contract allows anyone to sell and buy goods in a decentralized manner! The seller has to lock funds to avoid malicious behaviour.
        In addition, unhappy buyers can open a claim and the DAO will decide if the seller misbehaved or not.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract FP_Shop is IFP_Shop, AccessControlUpgradeable  {

    /************************************** Enum and structs *******************************************************/

    /**
        @dev A Sale can be in one of three states: 
        `Selling` deal still active
        `Disputed` the buyer submitted a claim
        `Pending` waiting buyer confirmation
        `Sold` deal is over, no claim was submitted
        `Vacation` the seller is on vacation, sale halted
    */
    enum State {
        Undefined,
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
        uint256 price;
        State state;
        uint256 buyTimestamp;
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

    /************************************** Constants *******************************************************/

    ///@notice The admin role ID for the AccessControl contract
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    ///@notice The DAO role ID for the AccessControl contract
    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
    ///@notice The blacklisted role ID for the AccessControl contract
    bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");
    ///@notice The maximum time a sale can be pending
    uint256 public MAX_PENDING_TIME = 30 days;

    /************************************** State vars *******************************************************/

    ///@notice Mapping between the item ID and its Sale struct
    mapping (uint256 => Sale) public offeredItems;
    ///@notice The index of the next new Sale
    uint256 public  offerIndex;
    ///@notice Mapping between the seller address and the number of valid sales
    mapping (address => uint256) public numValidSales;
    ///@notice Mapping between the seller address and the timestamp of the first valid sale
    mapping (address => uint256) public firstValidSaleTimestamp;
    ///@notice Mapping between the item ID and its Dispute struct
    mapping (uint256 => Dispute) public disputedItems;
    ///@notice The list of blacklisted seller addresses
    address[] public blacklistedSellers;
    ///@notice PowersellerNFT contract
    IFP_PowersellerNFT public powersellerContract;
    ///@notice Faillapop vault contract
    IFP_Vault public vaultContract;
    ///@notice Faillapop DAO contract
    IFP_DAO public daoContract;


    /************************************** Events and modifiers *****************************************************/
    
    ///@notice Emitted when a user buys an item, contains the user address and the item ID
    event Buy(address user, uint256 item);
    ///@notice Emitted when a user creates a new sale, contains the item ID and the title of the item
    event NewItem(uint256 id, string title);
    ///@notice Emitted when a user modifies a sale, contains the item ID and the title of the item
    event ModifyItem(uint256 id, string title);
    ///@notice Emitted when a user disputes a sale, contains the user address and the item ID
    event OpenDispute(address user, uint256 item);
    ///@notice Emitted when a user received a refund, contains the user address and the amount
    event Reimburse(address user, uint256 amount);
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
        @notice Initializer of the contract
        @param daoAddress The address of the DAO contract
        @param vaultAddress The address of the Vault contract
        @param powersellerNFTAddress The address of the PowersellerNFT contract
     */
    function initialize(address daoAddress, address vaultAddress, address powersellerNFTAddress) public initializer { 
        AccessControlUpgradeable.__AccessControl_init();
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DAO_ROLE, daoAddress);

        powersellerContract = IFP_PowersellerNFT(powersellerNFTAddress);
        daoContract = IFP_DAO(daoAddress);
        vaultContract = IFP_Vault(vaultAddress);
    }


    /**
        @notice Endpoint to buy an item
        @param itemId The ID of the item being bought
        @dev The user must send the exact amount of Ether to buy the item
     */
    function doBuy(uint256 itemId) external payable {
        require(offeredItems[itemId].seller != address(0), "itemId does not exist");
        require(offeredItems[itemId].state == State.Selling, "Item cannot be bought");
        require(msg.value >= offeredItems[itemId].price, "Incorrect amount of Ether sent");
        require(
            !hasRole(BLACKLISTED_ROLE, offeredItems[itemId].seller),
            "Seller is blacklisted"
        );
        
        offeredItems[itemId].buyer = msg.sender;
        offeredItems[itemId].state = State.Pending;
        offeredItems[itemId].buyTimestamp = block.timestamp;
        
        emit Buy(msg.sender, itemId);
    }
	

    /**
        @notice Endpoint to dispute a sale. The buyer will supply the supporting info to the DAO
        @param itemId The ID of the item being disputed
        @param buyerReasoning The reasoning of the buyer for the claim
     */
    function disputeSale(uint256 itemId, string calldata buyerReasoning) external {   
        require(offeredItems[itemId].state == State.Pending, "Item not pending"); 
        require(offeredItems[itemId].buyer == msg.sender, "Not the buyer");   

        offeredItems[itemId].state = State.Disputed;
        offeredItems[itemId].buyTimestamp = 0;

        // New dispute with ID = 0 until the correct one is set by the DAO
        Dispute memory newDispute = Dispute(0, buyerReasoning, "");
        disputedItems[itemId] = newDispute;
    }

    /**
        @notice Endpoint to confirm the receipt of an item and trigger the payment to the seller. 
        @param itemId The ID of the item being confirmed
     */
    function itemReceived(uint256 itemId) external {
        if(offeredItems[itemId].seller == msg.sender) {
            require( (block.timestamp - offeredItems[itemId].buyTimestamp) >= MAX_PENDING_TIME, "Insufficient elapsed time" );
        }else{
            require(offeredItems[itemId].buyer == msg.sender, "Not the buyer");
        }
        offeredItems[itemId].state = State.Sold;

        // Seller should be paid
        closeSale(itemId, false, true, true);
    }


    /**
        @notice Endpoint to close a dispute. Both the DAO and the buyer could call this function to cancel a dispute
        @param itemId The ID of the item being disputed
     */
    function endDispute(uint256 itemId) external {
        require(offeredItems[itemId].state == State.Disputed, "Dispute not found");

        if (msg.sender == offeredItems[itemId].buyer) {
            // Self-cancelation of the dispute, the buyer accepts the item
            _closeDispute(itemId);

        } else {
            // DAO resolving the dispute in favor of the seller, if the buyer wins `returnItem` will be called
            _checkRole(DAO_ROLE); // Will revert if msg.sender is doesn't have the DAO_ROLE
            delete disputedItems[itemId];
        }
          
        offeredItems[itemId].state = State.Sold;

        // Seller should be paid
        closeSale(itemId, false, true, true);
}

    /**
        @notice Endpoint to create a new sale. The seller must have enough funds staked in the Vault so  
            price amount can be locked to desincentivice malicious behavior
        @param title The title of the item being sold
        @param description A description of the item being sold
        @param price The price in Ether of the item being sold
     */
    function newSale(string calldata title, string calldata description, uint256 price) external notBlacklisted {
        require(price > 0, "Price must be greater than 0");
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");

        uint256 currentId = offerIndex;
        Sale memory sale = Sale(msg.sender, address(0), title, description, price, State.Selling, 0);
        offeredItems[currentId] = sale; 

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
        require(offeredItems[itemId].state == State.Selling, "Sale can't be modified");
        require(newPrice > 0, "Price must be greater than 0");
        require(bytes(newTitle).length > 0, "Title cannot be empty");
        require(bytes(newDesc).length > 0, "Description cannot be empty");
        require(offeredItems[itemId].seller == msg.sender, "Only the seller can modify the sale");   	
        
        // Update vault
        uint256 priceDifference;
        if (offeredItems[itemId].price > newPrice) {
            priceDifference = offeredItems[itemId].price - newPrice;
            vaultContract.doUnlock(msg.sender, priceDifference);
        } else if(offeredItems[itemId].price < newPrice) {
            priceDifference = newPrice - offeredItems[itemId].price; 
            vaultContract.doLock(msg.sender, priceDifference);
        }

        // Update details
        offeredItems[itemId].title = newTitle;         
        offeredItems[itemId].description = newDesc;    
        offeredItems[itemId].price = newPrice;

        emit ModifyItem(itemId, newTitle);
    }


    /**
        @notice Endpoint to cancel an active sale
        @param itemId The ID of the item which sale is being cancelled
    */
    function cancelActiveSale (uint256 itemId) external {    
        require(offeredItems[itemId].state == State.Selling, "Sale can't be cancelled");     
        require(offeredItems[itemId].seller == msg.sender, "Only the seller can cancel the sale");
        
        //Seller should NOT be paid
        closeSale(itemId, false, false, true);
    }    


    /**
        @notice Endpoint to set the vacation mode of a seller. If the seller is in vacation mode nobody can buy his goods
        @param vacationMode The new vacation mode of the seller
     */
    function setVacationMode(bool vacationMode) external {
        for (uint256 i = 0; i < offerIndex; i++) {
            if (offeredItems[i].seller == msg.sender) {

                if (vacationMode && offeredItems[i].state == State.Selling) {
                    offeredItems[i].state = State.Vacation;

                } else if (!vacationMode && offeredItems[i].state == State.Vacation) {
                    offeredItems[i].state = State.Selling;

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
    function disputedSaleReply(uint256 itemId, string calldata sellerReasoning) external {  
        require(offeredItems[itemId].state == State.Disputed, "Item not disputed");    
        require(offeredItems[itemId].seller == msg.sender, "Not the seller"); 
    
        _openDispute(itemId, sellerReasoning);
    }

    /** 
        @notice Endpoint to return an item, only the DAO can trigger it
        @param itemId The ID of the item being returned
     */
    function returnItem(uint256 itemId) external onlyRole(DAO_ROLE) {   
        require(offeredItems[itemId].state == State.Disputed, "Item not disputed");

        /*
        * A future functionality for dealing with returns will be implemented here!
        */

        delete disputedItems[itemId];
        closeSale(itemId, true, false, true);
    }

    /**
        @notice Endpoint to auto-claim the Powerseller badge. The user must have at least 10 valid sales and his first valid sale must be at least 5 weeks old
     */
    function claimPowersellerBadge() external {
        require(numValidSales[msg.sender] >= 10, "Not enough valid sales");
        require(block.timestamp - firstValidSaleTimestamp[msg.sender] >= 5 weeks, "Not enough time has elapsed"); 
        powersellerContract.safeMint(msg.sender);
    }

    /**
        @notice Endpoint to remove a malicious sale and slash the stake. The owner of the contract can remove a malicious sale and blacklist the seller
        @param itemId The ID of the item which sale is considered malicious
     */
    function removeMaliciousSale(uint256 itemId) external onlyRole(ADMIN_ROLE) {
        address seller = offeredItems[itemId].seller;
        require(seller != address(0), "itemId does not exist");

        _removePowersellerBadge(seller);
        _blacklist(seller); 

        if (offeredItems[itemId].state == State.Pending) {
            closeSale(itemId, true, false, false);
        } else if (offeredItems[itemId].state == State.Disputed) {
            closeSale(itemId, true, false, false);
            _closeDispute(itemId);
        } else {
            closeSale(itemId, false, false, false);
        }   
    }

    /************************************** Views  *******************************************************/ 

    /**
        @notice View function to return a disputed sale by its ID
        @param itemId The ID of the item being disputed
        @return The dispute details
     */
	function queryDispute (uint256 itemId) public view returns (Dispute memory) {
		return disputedItems[itemId];
	}

    /**
        @notice View function to return a sale by its ID
        @param itemId The ID of the sale
        @return The sale details
     */
    function querySale (uint256 itemId) public view returns (Sale memory) {
        return offeredItems[itemId];
    }

    /**
        @notice View function to return the number of valid sales of a seller
        @param seller The address of the seller
        @return The number of valid sales
     */
    function queryNumValidSales(address seller) public view returns (uint256) {
        return numValidSales[seller];
    }

    /************************************** Internal *****************************************************************/

    /**
        @notice Remove a sale from the list
        @param itemId The ID of the item which sale is being removed
        @param reimburseBuyer Whether the buyer should be reimbursed
        @param paySeller Whether the seller should be paid
        @param releaseSellerStake Whether the seller stake should be released
     */
    function closeSale(uint256 itemId, bool reimburseBuyer, bool paySeller, bool releaseSellerStake) public {
        address seller = offeredItems[itemId].seller;
        address buyer = offeredItems[itemId].buyer;
        uint256 price = offeredItems[itemId].price;  

        // Buyer reimbursement
        if (reimburseBuyer) {
            (bool success, ) = payable(buyer).call{value: price}(""); 
            require(success, "Sale payment failed");
            emit Reimburse(buyer, price);      
        }
        // Seller payment
        if (paySeller) {
            numValidSales[seller]++;
            if(numValidSales[seller] == 1) {
                firstValidSaleTimestamp[seller] = block.timestamp;
            }
            (bool success, ) = payable(seller).call{value: price}("");  
            require(success, "Sale payment failed");
        }
        // Seller stake release
        if (releaseSellerStake) {
            vaultContract.doUnlock(seller, price);
        }        

        delete offeredItems[itemId];
    }

    /**
        @notice Add a user to the seller blacklist and slash their funds in the Vault
        @param user The address of the seller
     */
    function _blacklist(address user) internal {
        grantRole(BLACKLISTED_ROLE, user);
        
        numValidSales[user] = 0;
        firstValidSaleTimestamp[user] = 0;

        //Slash the whole user stake
        vaultContract.doSlash(user);

        emit BlacklistSeller(user);
    }

    /**
        @notice Remove the powerseller badge from a malicious seller
        @param seller The address of the seller
     */
    function _removePowersellerBadge(address seller) internal {
        if(powersellerContract.checkPrivilege(seller)){
            powersellerContract.removePowersellerNFT(seller);
        }     
    }

    /** 
        @notice Open a dispute in the DAO contract
        @param itemId The ID of the item being disputed
        @param sellerReasoning The reasoning of the seller against the claim
     */
    function _openDispute(uint256 itemId, string calldata sellerReasoning) internal {
        address buyer = offeredItems[itemId].buyer;
        Dispute storage dispute = disputedItems[itemId]; 

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
    function _closeDispute(uint256 itemId) internal {
        uint256 dId = disputedItems[itemId].disputeId;
        // Forcefully cancel an ongoing dispute
        daoContract.cancelDispute(dId);

        delete disputedItems[itemId];
    }
}