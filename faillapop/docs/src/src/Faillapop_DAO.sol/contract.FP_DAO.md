# FP_DAO
[Git Source](https://github.com/jcr-security/solidity-security-teaching-resources/blob/7024bbd4dfb96e5bd0815e639fbc19b2a524a34b/src/Faillapop_DAO.sol)

**Author:**
Faillapop team :D

The contract allows to vote with FPT tokens on open disputes. If the dispute is resolved in favor of the buyer,
the seller have to refund the buyer. If the dispute is resolved in favor of the seller, the sale is closed.

*Security review is pending... should we deploy this?*


## State Variables
### THRESHOLD
Constants ******************************************************

The threshold for the random number generator


```solidity
uint256 constant THRESHOLD = 10;
```


### DEFAULT_QUORUM
The default number of voters for passing a vote


```solidity
uint256 constant DEFAULT_QUORUM = 100;
```


### disputes
Current disputes, indexed by disputeId


```solidity
mapping(uint256 => Dispute) public disputes;
```


### nextDisputeId
The ID of the next dispute to be created


```solidity
uint256 public nextDisputeId;
```


### hasVoted
*Mapping between user address and disputeId to record the vote. 1 is FOR, 2 is AGAINST*


```solidity
mapping(address => mapping(uint256 => uint256)) public hasVoted;
```


### disputeResult
*Mapping between disputeId and the result of the dispute. 1 is FOR, 2 is AGAINST*


```solidity
mapping(uint256 => uint8) public disputeResult;
```


### password
Password to access key features


```solidity
string private password;
```


### shop_addr
The address of the Shop contract


```solidity
address public shop_addr;
```


### shopContract
The Shop contract


```solidity
IFP_Shop public shopContract;
```


### nftContract
The NFT contract


```solidity
IFP_NFT public nftContract;
```


### fptContract
The FPT token contract


```solidity
IERC20 public fptContract;
```


### quorum
Min number of people to pass a proposal


```solidity
uint256 quorum;
```


## Functions
### isAuthorized

Check if the caller is authorized to access key features


```solidity
modifier isAuthorized(string calldata magicWord);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`magicWord`|`string`|The password to access key features|


### onlyShop

Check if the caller is the Shop contract


```solidity
modifier onlyShop();
```

### constructor

External  ***************************************************************

Constructor to set the password


```solidity
constructor(string memory magicWord, address shop, address nft_addr, address fpt_addr);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`magicWord`|`string`|The password to access key features|
|`shop`|`address`|The address of the Shop contract|
|`nft_addr`|`address`|The address of the NFT contract|
|`fpt_addr`|`address`|The address of the FPT token|


### updateConfig

Update the contract's configuration details


```solidity
function updateConfig(string calldata magicWord, string calldata newMagicWord, address newShop, address newNft)
    external
    isAuthorized(magicWord);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`magicWord`|`string`|to authenticate as privileged user|
|`newMagicWord`|`string`|The new password to access key features|
|`newShop`|`address`|The new address of the Shop contract|
|`newNft`|`address`|The new address of the NFT contract|


### castVote

Cast a vote on a dispute


```solidity
function castVote(uint256 disputeId, bool vote) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disputeId`|`uint256`|The ID of the target dispute|
|`vote`|`bool`|The vote, true for FOR, false for AGAINST|


### newDispute

Open a dispute


```solidity
function newDispute(uint256 itemId, string calldata buyerReasoning, string calldata sellerReasoning)
    external
    onlyShop
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item involved in the dispute|
|`buyerReasoning`|`string`|The reasoning of the buyer in favor of the claim|
|`sellerReasoning`|`string`|The reasoning of the seller against the claim|


### endDispute

Resolve a dispute if enough users have voted and remove it from the storage


```solidity
function endDispute(uint256 disputeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disputeId`|`uint256`|The ID of the target dispute|


### cancelDispute

Cancel an ongoing dispute. Either by the buyer or blacklisting (shop contract)


```solidity
function cancelDispute(uint256 disputeId) external onlyShop;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disputeId`|`uint256`|The ID of the target dispute|


### checkLottery

Randomly award an NFT to a user if they voten for the winning side


```solidity
function checkLottery(uint256 disputeId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disputeId`|`uint256`|The ID of the target dispute|


### lotteryNFT

Internal ****************************************************************

Run a PRNG to award NFT to a user


```solidity
function lotteryNFT(address user) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`user`|`address`|The address of the elegible user|


### buyerWins

Resolve a dispute in favor of the buyer triggering the Shop's return item and refund logic


```solidity
function buyerWins(uint256 itemId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item involved in the dispute|


### sellerWins

Resolve a dispute in favor of the seller triggering the Shop's close sale dispute logic


```solidity
function sellerWins(uint256 itemId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`itemId`|`uint256`|The ID of the item involved in the dispute|


### calcVotingPower

Calculate the voting power of a user


```solidity
function calcVotingPower(address user) internal returns (uint256);
```

### query_dispute

Views ********************************************************************

Query the details of a dispute


```solidity
function query_dispute(uint256 disputeId) public view returns (Dispute memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`disputeId`|`uint256`|The ID of the target dispute|


## Events
### NewConfig
Events and modifiers ****************************************************

Emitted when the contract configuration is changed, contains the address of the Shop


```solidity
event NewConfig(address shop, address nft);
```

### Vote
Emitted when a user votes, contains the disputeId and the user address


```solidity
event Vote(uint256 disputeId, address user);
```

### NewDispute
Emitted when a new dispute is created, contains the disputeId and the itemId


```solidity
event NewDispute(uint256 disputeId, uint256 itemId);
```

### EndDispute
Emitted when a dispute is closed, contains the disputeId and the itemId


```solidity
event EndDispute(uint256 disputeId, uint256 itemId);
```

### AwardNFT
Emitted when a user is awarder a cool NFT, contains the user address


```solidity
event AwardNFT(address user);
```

## Structs
### Dispute
State vars and Structs ******************************************************

A Dispute includes the itemId, the reasoning of the buyer and the seller on the claim,
and the number of votes for and against the dispute.

*A Dispute is always written from the POV of the buyer
- FOR is in favor of the buyer claim
- AGAINST is in favor of the seller claim*


```solidity
struct Dispute {
    uint256 itemId;
    string buyerReasoning;
    string sellerReasoning;
    uint256 votesFor;
    uint256 votesAgainst;
    uint256 totalVoters;
}
```

