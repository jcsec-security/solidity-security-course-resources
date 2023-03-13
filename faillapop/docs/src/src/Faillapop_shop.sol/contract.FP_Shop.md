# FP_Shop
[Git Source](https://github.com/jcr-security/solidity-security-teaching-resources/blob/7024bbd4dfb96e5bd0815e639fbc19b2a524a34b/src/Faillapop_shop.sol)

**Inherits:**
AccessControl

**Author:**
Faillapop team :D

The contract allows anyone to sell and buy goods in a decentralized manner! The seller has to lock funds to avoid malicious behaviour.
In addition, unhappy buyers can open a claim and the DAO will decide if the seller misbehaved or not.

*Security review is pending... should we deploy this?*


## State Variables
### ADMIN_ROLE
Constants ******************************************************

The admin role ID for the AccessControl contract


```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
```


### DAO_ROLE
The DAO role ID for the AccessControl contract


```solidity
bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");
```


### BLACKLISTED_ROLE
The blacklisted role ID for the AccessControl contract


```solidity
bytes32 public constant BLACKLISTED_ROLE = keccak256("BLACKLISTED_ROLE");
```


### offered_items
Mapping between the item ID and its Sale struct


```solidity
mapping(uint256 => Sale) public offered_items;
```


### offerIndex
The index of the next new Sale


```solidity
uint256 public offerIndex;
```


### disputed_items
Mapping between the itemId the Shop's dispute struct


```solidity
mapping(uint256 => Dispute) public disputed_items;
```


### blacklistedSellers
The list of blacklisted seller addresses


```solidity
address[] public blacklistedSellers;
```


### vaultContract
Faillapop vault contract


```solidity
IFP_Vault public vaultContract;
```


### daoContract
Faillapop DAO contract


```solidity
IFP_DAO public daoContract;
```


## Functions
### notBlacklisted

Check if the caller is not blacklisted


```solidity
modifier notBlacklisted();
```

### constructor

External  ***************************************************************

Constructor of the contract


```solidity
constructor(address dao_addr, address vault_addr);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`dao_addr`|`address`|The address of the DAO contract|
|`vault_addr`|`address`|The address of the Vault contract|


### doBuy

Endpoint to buy an item

*The user must send the exact amount of Ether to buy the item*


```solidity
function doBuy(uint256 itemId) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being bought|


### disputeSale

Endpoint to dispute a sale. The buyer will supply the supporting info to the DAO


```solidity
function disputeSale(uint256 itemId, string calldata buyerReasoning) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being disputed|
|`buyerReasoning`|`string`|The reasoning of the buyer for the claim|


### itemReceived

Endpoint to confirm the receipt of an item and trigger the payment to the seller.


```solidity
function itemReceived(uint256 itemId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being confirmed|


### endDispute

Endpoint to close a dispute. Both the DAO and the buyer could call this function to cancel a dispute


```solidity
function endDispute(uint256 itemId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being disputed|


### newSale

Endpoint to create a new sale. The seller must have enough funds staked in the Vault so
price amount can be locked to desincentivice malicious behavior


```solidity
function newSale(string calldata title, string calldata description, uint256 price) external notBlacklisted;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`title`|`string`|The title of the item being sold|
|`description`|`string`|A description of the item being sold|
|`price`|`uint256`|The price in Ether of the item being sold|


### modifySale

Endpoint to modify an existing sale. Locked funds will be partially realeased if price decreases.


```solidity
function modifySale(uint256 itemId, string calldata newTitle, string calldata newDesc, uint256 newPrice) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|ID of the item being modified|
|`newTitle`|`string`|New title of the item being sold|
|`newDesc`|`string`|New description of the item being sold|
|`newPrice`|`uint256`|New price in Ether of the item being sold|


### cancelActiveSale

Endpoint to cancel an active sale


```solidity
function cancelActiveSale(uint256 itemId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item which sale is being cancelled|


### setVacationMode

Endpoint to set the vacation mode of a seller. If the seller is in vacation mode nobody can buy his goods


```solidity
function setVacationMode(bool _vacationMode) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_vacationMode`|`bool`|The new vacation mode of the seller|


### disputedSaleReply

Endpoint to reply to a dispute. The seller will supply the supporting info to the DAO. If the seller does not reply,
the admin could mark them as malicious and slash their funds


```solidity
function disputedSaleReply(uint256 itemId, string calldata sellerReasoning) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being disputed|
|`sellerReasoning`|`string`|The reasoning of the seller for the claim|


### returnItem

Endpoint to return an item, only the DAO can trigger it


```solidity
function returnItem(uint256 itemId) external onlyRole(DAO_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being returned|


### removeMaliciousSale

Endpoint to remove a malicious sale and slash the stake. The owner of the contract can remove a malicious sale and blacklist the seller


```solidity
function removeMaliciousSale(uint256 itemId) external onlyRole(ADMIN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item which sale is considered malicious|


### closeSale

Internal ****************************************************************

Remove a sale from the list


```solidity
function closeSale(uint256 itemId, bool toBePaid) public;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item which sale is being removed|
|`toBePaid`|`bool`|If the seller should be paid or not|


### blacklist

Add a user to the seller blacklist and slash their funds in the Vault


```solidity
function blacklist(address user) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the seller|


### reimburse

Reimburse a buyer.


```solidity
function reimburse(uint256 itemId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being reimbursed|


### openDispute

Open a dispute in the DAO contract


```solidity
function openDispute(uint256 itemId, string calldata sellerReasoning) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being disputed|
|`sellerReasoning`|`string`|The reasoning of the seller against the claim|


### closeDispute

Close a dispute in the DAO contract, either due to blacklisting or the buyer deciding not
to pursue the dispute


```solidity
function closeDispute(uint256 itemId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being disputed|


### query_dispute

Views  ******************************************************

View function to return the user's disputed sales


```solidity
function query_dispute(uint256 itemId) public view returns (Dispute memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item being disputed|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`Dispute`|The dispute details|


### query_sale


```solidity
function query_sale(uint256 itemId) public view returns (Sale memory);
```

## Events
### Buy
Events and modifiers ****************************************************

Emitted when a user buys an item, contains the user address and the item ID


```solidity
event Buy(address user, uint256 item);
```

### NewItem
Emitted when a user creates a new sale, contains the item ID and the title of the item


```solidity
event NewItem(uint256 id, string title);
```

### ModifyItem
Emitted when a user modifies a sale, contains the item ID and the title of the item


```solidity
event ModifyItem(uint256 id, string title);
```

### OpenDispute
Emitted when a user disputes a sale, contains the user address and the item ID


```solidity
event OpenDispute(address user, uint256 item);
```

### Reimburse
Emitted when a user received a refund, contains the user address and the amount


```solidity
event Reimburse(address user, uint256 amount);
```

### AwardNFT
Emitted when a user receives an reward NFT, contains the user address


```solidity
event AwardNFT(address user);
```

### BlacklistSeller
Emitted when a user is blacklisted, contains the user address


```solidity
event BlacklistSeller(address seller);
```

## Structs
### Sale
*A Sale struct represent each of the active sales in the shop.*


```solidity
struct Sale {
    address seller;
    address buyer;
    string title;
    string description;
    uint256 price;
    State state;
}
```

### Dispute
*A Dispute struct represent each of the active disputes in the shop.*


```solidity
struct Dispute {
    uint256 disputeId;
    string buyerReasoning;
    string sellerReasoning;
}
```

## Enums
### State
State vars  and Structs ******************************************************

*A Sale can be in one of three states:
`Selling` deal still active
`Disputed` the buyer submitted a claim
`Pending` waiting buyer confirmation
`Sold` deal is over, no claim was submitted
`Vacation` the seller is on vacation, sale halted*


```solidity
enum State {
    Selling,
    Pending,
    Disputed,
    Sold,
    Vacation
}
```

