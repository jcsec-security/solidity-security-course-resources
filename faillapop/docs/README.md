## Architecture 🏗️
The protocol consists of multiple interconnected smart contracts, each serving a specific role in the ecosystem:
- **FP_Shop** 🛒: Facilitates the marketplace functionality, including listing items, handling purchases, and managing sales
- **FP_DAO** ⚖️: Manages voting on disputes using FPT tokens and commit-reveal schemes, and handles upgrade proposals for the Shop contract
- **FP_Vault** 💰: Allows users to stake and unstake funds, lock funds during sales, and claim rewards from slashed malicious users
- **FP_PowersellerNFT** 🏅: Grants a Powerseller NFT badge to legitimate users, enabling specific privileges within the ecosystem
- **FP_CoolNFT** 🆒: Represents a Cool NFT that can be minted by the DAO as a reward for participating in governance and dispute resolution. Serving as a badge of active users in the community
- **FP_Proxy** 🔄: Implements a proxy pattern using EIP-1967, enabling seamless `FP_SHOP` upgrades while preserving storage data
- **FP_Token** 🪙: An ERC20 token used for governance purposes within the protocol

These contracts interact seamlessly to ensure that marketplace operations are conducted efficiently while maintaining a high level of security and transparency 🔒

## Use Cases 💡
### Real-World Applications 🌍
1. **E-commerce Transactions** 🛍️: Users can buy and sell goods securely using Faillapop, leveraging the Powerseller NFT for enhanced trust
2. **Dispute Resolution** ⚖️: The FP_DAO allows users to resolve disputes through decentralized secret-voting, ensuring fair outcomes without centralized intervention
3. **Governance Proposals** 📈: Users can propose and vote on upgrades to the marketplace infrastructure, ensuring continuous improvement and adaptation

## Security 🛡️
Faillapop prioritizes security through several measures:
- **Access Control** 🛡️: Contracts utilize OpenZeppelin’s AccessControl to manage roles and permissions, reducing the attack surface for unauthorized actions
- **Audits and Reviews** 🔍: Faillapop contracts do not need to be audited as it has been developed by experienced, badass developers 😎
- **Community Vigilance** 👥: However, users are encouraged to participate in bug bounties and security assessments to enhance overall protocol resilience

The combination of robust governance, secure architecture, and real-world applicability positions Faillapop as a leading solution for decentralized marketplace operations, fostering trust and reliability among its users 🤝


# FP_Shop Smart Contract Documentation 🛒📜

## Description

The `FP_Shop` 🛒 contract is a decentralized marketplace allowing users to buy and sell goods in a secure manner. Sellers must lock funds to prevent malicious behavior, and buyers can open disputes if they are unhappy with their purchase. Disputes are resolved by a DAO, which can lead to refunds or other actions

## Dependencies 🔗

- `IFP_DAO`: Interface for the FP_DAO contract
- `IFP_Vault`: Interface for the FP_Vault contract
- `IFP_CoolNFT`: Interface for the FP_CoolNFT contract
- `IFP_PowersellerNFT`: Interface for the FP_PowersellerNFT contract
- `Initializable` from OpenZeppelin

## Inheritance 🧬
- `AccessControlUpgradeable` from OpenZeppelin: Provides a way to control access to functions based on roles
- `IFP_Shop`: Interface for the FP_Shop contract
  
## Enums
- `State`: 
  - `Undefined`
  - `Selling`
  - `Pending`
  - `Disputed`
  - `Sold`
  - `Vacation`
  
## Structs 📦
- `Sale`: Represent each of the active sales in the shop
  -  `seller` - address
  -  `buyer` - address
  -  `title` - string
  -  `description` - string
  -  `price` - uint256
  -  `state` of Type `State`
  -  `buyTimestamp` - uint256
  
- `Dispute`: Represent each of the active disputes in the shop
  - `itemId` - uint256
  - `disputeTimestamp` - uint256
  - `buyerReasoning` - string
  - `sellerReasoning` - string

## Constants 🔢
- `ADMIN_ROLE`: Role identifier for admin - (keccak256("ADMIN_ROLE"))
- `DAO_ROLE`: Role identifier for DAO - (keccak256("DAO_ROLE"))
- `BLACKLISTED_ROLE`: Role identifier for blacklisted users - (keccak256("BLACKLISTED_ROLE"))
- `MAX_DISPUTE_WAITING_FOR_REPLY`: Maximum time that a dispute can be kept waiting for a seller's reply
- `MAX_PENDING_TIME`: Maximum time a sale can be pending - (30 days)

## State Variables 📂
- `offeredItems`: Mapping from item ID to `Sale` struct
- `offerIndex`: Index of the next new sale
- `numValidSales`: Mapping from seller address to the number of valid sales
- `firstValidSaleTimestamp`: Mapping from seller address to the timestamp of the first valid sale
- `disputedItems`: Mapping from item ID to `Dispute` struct
- `blacklistedSellers`: List of blacklisted seller addresses
- `powersellerContract`: Faillapop PowersellerNFT contract
- `coolNFTContract`: Faillapop CoolNFT contract
- `vaultContract`: Faillapop Vault contract
- `daoContract`: Faillapop DAO contract

## Events 📢

- `Buy(address user, uint256 item)`: Emitted when a user buys an item
- `NewItem(uint256 id, string title)`: Emitted when a new item is listed for sale
- `ModifyItem(uint256 id, string title)`: Emitted when a sale is modified
- `OpenDispute(address user, uint256 item)`: Emitted when a sale is disputed
- `Reimburse(address user, uint256 amount)`: Emitted when a user is reimbursed
- `AwardNFT(address user)`: Emitted when a user receives a reward NFT
- `BlacklistSeller(address seller)`: Emitted when a seller is blacklisted

## Modifiers

- `notBlacklisted()`: Ensures the caller is not blacklisted

## Functions 🛠️

### `initialize(address daoAddress, address vaultAddress, address powersellerNFTAddress, address coolNFTAddress)`

Initializes the contract, setting up roles and linking necessary external contracts

**Parameters:**
- `daoAddress`: The address of the DAO contract
- `vaultAddress`: The address of the Vault contract
- `powersellerNFTAddress`: The address of the PowersellerNFT contract
- `coolNFTAddress`; The address of the CoolNFT contract
  
**Requirements:** 
- Only can be called once
  
***

### `doBuy(uint256 itemId)`

Allows a user to buy an item by sending the required amount of Ether. The item must be in a selling state, and the seller must not be blacklisted. Updates the state of the sale and records the buyer's information

**Parameters:**
- `itemId`: The ID of the item being bought

**Requirements:** 
- The item must exist
- The item must be in a selling state
- The amount of Ether sent must not be less than the price of the item
- Seller must not be blacklisted
  
***

### `disputeSale(uint256 itemId, string calldata buyerReasoning)`

Allows a buyer to dispute a sale if they are unhappy with the item. The sale must be in a pending state, and the caller must be the buyer. The sale's state is updated to disputed, and a new dispute record is created

**Parameters:**
- `itemId`: The ID of the item being disputed
- `buyerReasoning`: The buyer's reasoning for the dispute

**Requirements:** 
- The sale must be in a pending state
- The caller must be the buyer
  
***

### `itemReceived(uint256 itemId)`

Confirms the receipt of an item, triggering the payment to the seller. Can be called by either the buyer or the seller (after a certain time period). Updates the state of the sale to sold and processes the payment

**Parameters:**
- `itemId`: The ID of the item being confirmed

**Requirements:** 
- Only can be called by the buyer or the seller
- If the caller is the seller, the sale must be in a pending state
  
***

### `endDispute(uint256 itemId)`

Ends a dispute, either by the buyer self-canceling or by the DAO resolving it. If resolved in favor of the seller, the sale is marked as sold and payment is processed. 
In case of a seller unresponsive, the buyer can cancel the dispute and get a refund (`MAX_DISPUTE_WAITING_FOR_REPLY` time has to be elapsed)

**Parameters:**
- `itemId`: The ID of the item being disputed

**Requirements:** 
- The sale must be in a disputed state
  
***

### `newSale(string calldata title, string calldata description, uint256 price)`

Creates a new sale listing. The seller must lock funds in the vault equivalent to the sale price to discourage malicious behavior. Adds the new sale to the `offeredItems` mapping and increments the `offerIndex`

**Parameters:**
- `title`: The title of the item being sold
- `description`: A description of the item being sold
- `price`: The price in Ether of the item being sold

**Requirements:** 
- The seller must not be blacklisted
- Price must be greater than 0
- Seller must have enough funds in the vault
- Title and description must not be empty
  
***

### `modifySale(uint256 itemId, string calldata newTitle, string calldata newDesc, uint256 newPrice)`

Modifies an existing sale's details. Only the seller can modify the sale, and the sale must be in a selling state. Updates the locked funds in the vault if the price changes

**Parameters:**
- `itemId`: The ID of the item being modified
- `newTitle`: The new title of the item
- `newDesc`: The new description of the item
- `newPrice`: The new price of the item

**Requirements:** 
- The caller must be the seller
- The sale must be in a selling state
- The new price must be greater than 0
- The seller must have enough funds in the vault
- The new title and description must not be empty
  
***

### `cancelActiveSale(uint256 itemId)`

Cancels an active sale. Only the seller can cancel the sale, and the sale must be in a selling state. Unlocks the seller's staked funds in the vault

**Parameters:**
- `itemId`: The ID of the item being cancelled

**Requirements:** 
- The caller must be the seller
- The sale must be in a selling state
  
***

### `setVacationMode(bool vacationMode)`

Sets the vacation mode for a seller. When in vacation mode, the seller's items cannot be bought

**Parameters:**
- `vacationMode`: The new vacation mode of the seller
  
***

### `disputedSaleReply(uint256 itemId, string calldata sellerReasoning)`

Allows the seller to reply to a dispute with their reasoning. The sale must be in a disputed state, and the caller must be the seller. The seller's reasoning is recorded in the dispute.
If the seller does not reply in time, the admin could mark them as malicious and slash their funds, or the buyer could cancel the dispute and get a refund

**Parameters:**
- `itemId`: The ID of the item being disputed
- `sellerReasoning`: The seller's reasoning for the dispute

**Requirements:** 
- The sale must be in a disputed state
- The caller must be the seller
  
***

### `returnItem(uint256 itemId)`

Allows the DAO to return an item, indicating the resolution of a dispute in favor of the buyer. The sale's state is updated, and the dispute record is deleted

**Parameters:**
- `itemId`: The ID of the item being returned

**Requirements:** 
- The sale must be in a disputed state
- The caller must be the DAO
  
***
  
### `claimPowersellerBadge()`

Allows a user to claim the Powerseller badge if they meet the criteria: at least 10 valid sales and the first valid sale being at least 5 weeks old

**Requirements:** 
- The caller must have enough valid sales (10 at least)
- The caller's first valid sale must be at least 5 weeks old
- The `safeMint` low-level call must not revert
  
***

### `removeMaliciousSale(uint256 itemId)`

Allows the admin to remove a malicious sale and blacklist the seller. Depending on the sale's state, it may also reimburse the buyer and/or close a dispute. It will also slash the seller's NFT (powerseller and CoolNFT) if they have them

**Parameters:**
- `itemId`: The ID of the item considered malicious

**Requirements:** 
- The caller must have the admin role
- The sale must exist
  
***

## Internal Functions

### `closeSale(uint256 itemId, bool reimburseBuyer, bool paySeller, bool releaseSellerStake)`

Closes a sale, optionally reimbursing the buyer, paying the seller, and/or releasing the seller's staked funds

**Parameters:**
- `itemId`: The ID of the item being closed
- `reimburseBuyer`: Whether to reimburse the buyer
- `paySeller`: Whether to pay the seller
- `releaseSellerStake`: Whether to release the seller's staked funds

**Requirements:** 
- Low-level calls must not revert
  
***

### `_blacklist(address user)`

Blacklists a seller, slashing their funds in the vault and resetting their valid sales count and timestamp

**Parameters:**
- `user`: The address of the seller to be blacklisted
  
***

### `_removePowersellerBadge(address seller)`

Removes the Powerseller badge from a seller if they have one

**Parameters:**
- `seller`: The address of the seller
  
***

### `_removeCoolNFTs(address seller)`

Removes the CoolNFTs from a seller if they have any

**Parameters:**
- `seller`: The address of the seller
  
***

### `_openDispute(uint256 itemId, string calldata sellerReasoning)`

Opens a dispute in the DAO contract, recording the seller's reasoning

**Parameters:**
- `itemId`: The ID of the item being disputed
- `sellerReasoning`: The seller's reasoning against the claim
  
***

### `_closeDispute(uint256 itemId)`

Closes a dispute in the DAO contract, either due to blacklisting or the buyer deciding not to pursue it

**Parameters:**
- `itemId`: The ID of the item being disputed

***

# FP_DAO Contract Documentation ⚖️📜

## Description
The FP_DAO ⚖️ contract allows voting with FPT tokens on open disputes. If a dispute is resolved in favor of the buyer, the seller must refund the buyer. If resolved in favor of the seller, the sale is closed The contract also facilitates upgrade proposals for the Shop contract

## Dependencies 🔗
- `IFP_CoolNFT`: Interface for the FP_CoolNFT contract
- `IFP_Shop`: Interface for the FP_Shop contract 
- `IERC20` from OpenZeppelin

## Inheritance 🧬
- `AccessControl` from OpenZeppelin: Provides a way to control access to functions based on roles
- `IFP_DAO`: Interface for the FP_DAO contract

## Enums
- `DisputeState`: 
  - `NOT_ACTIVE`
  - `COMMITTING_PHASE`
  - `REVEALING_PHASE`
- `ProposalState`:
  - `NOT_ACTIVE`
  - `ACTIVE`
  - `PASSED`
- `Vote`
  - `DIDNT_VOTE`
  - `COMMITTED`
  - `FOR`
  - `AGAINST`
  
## Structs 📦
- `Dispute`: Represent each of the active disputes
  -  `itemId` - uint256
  -  `buyerReasoning` - string
  -  `sellerReasoning` - string
  -  `votesFor` - uint256
  -  `votesAgainst` - uint256
  -  `totalVoters` - uint256
  -  `committingStartingTime` - uint256
  -  `revealingStartingTime` - uint256
  -  `state` of type `DisputeState`
  
- `UpgradeProposal`: Represent each of the active upgrade proposals
  - `creator` - address
  - `id` - uint256
  - `creationTimestamp` - uint256
  - `approvalTimestamp` - uint256
  - `newShop` - address
  - `votesFor` - uint256
  - `votesAgainst` - uint256
  - `totalVoters` - uint256
  - `state` of type `ProposalState`

## Constants 🔢
- `THRESHOLD`: Threshold for the random number generator - (10)
- `DEFAULT_DISPUTE_QUORUM`: Default number of voters for passing a dispute vote - (100)
- `COMMITTING_TIME`: Minimum committing period for votes on a dispute - (3 days)
- `MIN_REVEALING_TIME`: Minimum revealing period for votes on a dispute - (1 day)
- `MAX_REVEALING_TIME`: Maximum revealing period for votes on a dispute - (3 days)
- `DEFAULT_PROPOSAL_QUORUM`: Default number of voters for passing an update vote - (500)
- `PROPOSAL_REVIEW_TIME`: Time window in which a proposal can not be voted - (1 day)
- `PROPOSAL_VOTING_TIME`: Minimum voting period for a proposal - (3 days)
- `PROPOSAL_EXECUTION_DELAY`: Minimum waiting time between approval and execution of a proposal - (1 day)
- `CONTROL_ROLE`: Control role ID for the AccessControl contract At first it's the msgsender and then the shop - (keccak256("CONTROL_ROLE"))

## Immutables
- `COOL_NFT_CONTRACT`: Address of the CoolNFT contract
- `FPT_CONTRACT`: Address of the FPT token contract

## State Variables 📂
- `_shopSet`: Bool to check if the shop address has been set
- `disputes`: Mapping from dispute ID to `Dispute` struct
- `nextDisputeId`: The ID of the next dispute to be created
- `commitsOnDisputes`: Mapping between disputeId and user address to record the hash of the vote + secret 
- `hasVotedOnDispute`: Mapping between user address and disputeId to record the vote
- `disputeResult`: Mapping between disputeId and the result of the dispute
- `hasCheckedLottery`: Mapping between user address and disputeId to record the lottery check
- `disputeQuorum`: Min number of people to pass a dispute
- `upgradeProposals`: Current upgrade proposals, indexed by upgradeProposalId
- `nextUpgradeProposalId`: The ID of the next upgrade proposal to be created
- `hasVotedOnUpgradeProposal`: Mapping between user address and upgradeProposalId to record the vote
- `upgradeProposalResult`: Mapping between upgradeProposalId and the result of the proposal
- `proposalQuorum`: Min number of people to pass a proposal
- `_password`: Password to access key features
- `shopAddress`: Address of the Shop contract

## Errors
- `ZeroAddress`: Throwed if a zero address (0x0) is detected in an operation that does not permit it

## Events 📢
- `DisputeVoteCommitted(uint disputeId, address user)`: Emitted when a user commits a vote on a dispute
- `DisputeVoteCasted(uint256 disputeId, address user)`: Emitted when a user casts a vote on a dispute
- `NewDispute(uint256 disputeId, uint256 itemId)`: Emitted when a new dispute is opened
- `EndDispute(uint256 disputeId, uint256 itemId)`: Emitted when a dispute is resolved
- `AwardNFT(address user)`: Emitted when a user receives a CoolNFT
- `NewUpgradeProposal(uint256 id, uint256 creationTimestamp, address newShop)`: Emitted when a new upgrade proposal is opened
- `ProposalVoteCasted(uint256 proposalId, address user)`: Emitted when a user casts a vote on an upgrade proposal
- `ProposalPassed(uint256 proposalId, address newShop, uint256 approvalTimestamp)`: Emitted when an upgrade proposal passes
- `ProposalNotPassed(uint256 proposalId, address newShop)`: Emitted when an upgrade proposal does not pass
- `ProposalExecuted(uint256 proposalId, address newShop)`: Emitted when an upgrade proposal is executed
- `ProposalCanceled(uint256 proposalId)`: Emitted when an upgrade proposal is canceled

## Modifiers
- `isAuthorized(string calldata magicWord)`: Ensures caller is authorized by checking the password
- `shopNotSet()`: Ensures the shop address has not been set
- `notZero(address toCheck)`: Ensures the provided address is not zero
- `notChecked(address user, uint256 disputeId)`: Ensures the user has not checked the lottery for the dispute

## Functions 🛠️

### `constructor(string memory magicWord, address nftAddress, address fptAddress)`

Initializes the contract with the provided password, NFT contract address, and FPT token address

**Parameters:** 
  - `magicWord`: password to access key features
  - `nftAddress`: address of the CoolNFT contract
  - `fptAddress`: address of the FPT token
  
***

### `setShop(address shop)`

Sets the shop address and assigns it the CONTROL_ROLE

**Parameters:** 
  - `shop`: address of the shop

**Requirements:**  
  - It can only be called once
  - It can only be called by the deployer
  
***

### `newDispute(uint256 itemId, string calldata buyerReasoning, string calldata sellerReasoning)`

Opens a new dispute

**Parameters:** 
  - `itemId`: The ID of the item involved in the dispute
  - `buyerReasoning`: The reasoning of the buyer in favor of the claim
  - `sellerReasoning`: The reasoning of the seller against the claim

**Requirements:**  
  - Caller must be the shop
  
***

### `commitVoteOnDispute(uint256 disputeId, bytes32 commit)`

Commits the hash of the vote for a dispute

**Parameters:** 
  - `disputeId`: The ID of the target dispute
  - `commit`: Vote + secret hash

**Requirements:**  
  - The dispute must be in the committing phase
  - The user must not have already committed a vote
  
***

### `revealDisputeVote(uint disputeId, bool vote, string calldata secret)`

Reveals a vote on a dispute

**Parameters:** 
  - `disputeId`: The ID of the target dispute
  - `vote`: The vote of the user
  - `secret`: The secret used to commit the vote

**Requirements:** 
    - The dispute must be in the revealing phase or the dispute is in the committing phase and the committing time has passed (3 days minimum)
    - The user must have committed a vote
    - The secret must match the commit
  
***

### `endDispute(uint256 disputeId)`

Resolves a dispute and removes it from storage

**Parameters:** 
  - `disputeId`: The ID of the target dispute

**Requirements:**  
  - The dispute must be in the revealing phase
  - Revealing time must have passed (1 day minimum)
  - The dispute must have enough votes (quorum) or the maximum revealing time has passed (3 days)
  
***
  
### `cancelDispute(uint256 disputeId)`

Cancels an ongoing dispute

**Parameters:** 
  - `disputeId`: The ID of the target dispute

**Requirements:**  
  - Caller must be the shop
  
***

### `checkLottery(uint256 disputeId)`

Awards an NFT to a user if they voted for the winning side

**Parameters:** 
  - `disputeId`: The ID of the target dispute

**Requirements:** 
  - User must have voted on the winning side
  - User must not have already checked the lottery
  
***

### `newUpgradeProposal(address addrNewShop)`

Opens an upgrade proposal

**Parameters:** 
  - `addrNewShop`: The address of the new Shop contract proposed

**Requirements:**  
  - The new address must not be zero (0x0)
  - The new address must have code (be a contract)
  
***

### `castVoteOnProposal(uint256 proposalId, bool vote)`

Casts a vote on an upgrade proposal

**Parameters:** 
  - `proposalId`: The ID of the upgrade proposal
  - `vote`: The vote, true for FOR, false for AGAINST

**Requirements:**  
  - The proposal must be active
  - The review time must have passed (1 day minimum)
  - The user must not have already voted
  - The user must have FPT tokens (voting power)
  
***

### `cancelProposalByCreator(uint256 proposalId)`

Cancels an ongoing upgrade proposal by the creator

**Parameters:** 
  - `proposalId`: The ID of the upgrade proposal
  
**Requirements:**  
  - The proposal must be active
  - The creator must be the sender
  
***

###  `cancelProposal(uint256 proposalId, string calldata magicWord)`

Cancels an ongoing upgrade proposal by the admin

**Parameters:** 
  - `proposalId`: The ID of the upgrade proposal
  - `magicWord`: The password to access key features

**Requirements:** 
  - The password must match    
  
***

### `resolveUpgradeProposal(uint256 proposalId)`

Resolves an upgrade proposal

**Parameters:** 
  - `proposalId`: The ID of the upgrade proposal

**Requirements:**  
  - The proposal must be active
  - The voting time must have passed (3 days minimum)
  - The proposal must have enough votes (quorum)
  
***

### `executePassedProposal(uint256 proposalId)` 

Executes a passed upgrade proposal

**Parameters:** 
  - `proposalId`: The ID of the upgrade proposal

**Requirements:**  
  - The proposal must have passed
  - The execution delay must have passed (1 day minimum)
  - The `upgradeToAndCall` low-level call must not revert
  
***

### `queryDispute(uint256 disputeId)`

Query the details of a dispute

**Parameters:** 
  - `disputeId`: The ID of the target dispute
  
***
  
### `queryDisputeResult(uint256 disputeId)`

Query the result of a dispute

**Parameters:** 
  - `disputeId`: The ID of the target dispute
  
***
  
### `queryUpgradeProposal(uint256 upgradeProposalId)`

Query the details of an upgrade proposal

**Parameters:** 
  - `upgradeProposalId`: The ID of the target proposal
  
***
  
### `queryUpgradeProposalResult(uint256 upgradeProposalId)`

Query the result of an upgrade proposal

**Parameters:** 
  - `upgradeProposalId`: The ID of the target proposal
  
***

## Internal Functions
  
### `_lotteryNFT(address user)`

Run a PRNG to award NFT to a user

**Parameters:** 
  - `user`: The address of the elegible user
  
***
  
### `_buyerWins(uint256 itemId)`

Resolve a dispute in favor of the buyer triggering the Shop's return item and refund logic

**Parameters:** 
  - `itemId`: The ID of the item involved in the dispute

**Requirements:**  
  - The `returnItem` low-level call must not revert
  
***

### `_sellerWins(uint256 itemId)`

Resolve a dispute in favor of the seller triggering the Shop's close sale dispute logic

**Parameters:** 
  - `itemId`: The ID of the item involved in the dispute

**Requirements:**  
  - The `endDispute` low-level call must not revert
  
***
  
### `_calcVotingPower(address user)`

Calculate the voting power of a user

**Parameters:** 
  - `user`: The address of the user to calculate the voting power
  
***
  
### `_cancelProposal(uint proposalId)`

Cancel an ongoing upgrade proposal Either by the sender of the proposal or the admin (who knows the password)

**Parameters:** 
  - `proposalId`: The ID of the upgrade proposal
  
***
  
# FP_Vault Contract Documentation 💰📜

## Description
The FP_Vault 💰 contract allows users to stake and unstake Ether. Funds can also be locked during the selling process in the shop, and slashed if a user is deemed malicious by the DAO. Rewards can be claimed for slashing malicious users

## Dependencies 🔗
- `IFP_Shop`: Interface for the FP_Shop contract

## Inheritance 🧬
- `AccessControl` from OpenZeppelin: Provides a way to control access to functions based on roles
- `IFP_Vault`: Interface for the FP_Vault contract

## Constants 🔢
- `DAO_ROLE`: DAO role ID for the AccessControl contract - (`keccak256("DAO_ROLE")`)
- `CONTROL_ROLE`: Shop role ID for the AccessControl contract - (`keccak256("CONTROL_ROLE")`)

## Immutable
- `POWERSELLER_CONTRACT`: Address of the powerseller NFT contract

## State Variables 📂
- `_shopSet`: Bool to check if the shop address has been set
- `balance`: Mapping from user address to their staked balance
- `lockedFunds`: Mapping from user address to their locked funds
- `maxClaimableAmount`: Maximum amount of rewards that can be claimed per user
- `rewardsClaimed`: Mapping from user address to the amount of rewards claimed
- `totalSlashed`: Total amount of funds slashed

## Events 📢
- `Stake(address indexed user, uint256 amount)`: Emitted when a user stakes funds
- `Unstake(address indexed user, uint256 amount)`: Emitted when a user unstakes funds
- `Locked(address indexed user, uint256 amount)`: Emitted when funds are locked for selling
- `Unlocked(address indexed user, uint256 amount)`: Emitted when locked funds are unlocked
- `Slashed(address indexed user, uint256 amount)`: Emitted when funds are slashed due to malicious behavior
- `RewardsClaimed(address indexed user, uint256 amount)`: Emitted when rewards are claimed by a user

## Modifiers
- `enoughStaked(address user, uint256 amount)`: Ensures the user has enough staked funds
- `shopNotSet()`: Ensures the shop address has not been set

## Functions 🛠️

### `constructor(address powersellerNFT, address dao)`

Initializes the contract with the powerseller NFT contract address and the DAO contract address

**Parameters:** 
- `powersellerNFT`: Address of the powerseller NFT contract
- `dao`: Address of the DAO contract

***

### `setShop(address shopAddress)`

Sets the shop address and assigns it the CONTROL_ROLE

**Parameters:** 
- `shopAddress`: Address of the shop contract

**Requirements:**  
- Can only be called once
- Can only be called by the deployer

***

### `doStake()`

Stakes attached funds in the vault for later locking. Users must execute this function on their own

**Requirements:**  
- `msg.value` must be greater than zero

***

### `doUnstake(uint256 amount)`

Unstakes unlocked funds from the vault. Users must execute this function on their own

**Parameters:** 
- `amount`: Amount of funds to unstake

**Requirements:**  
- User must have enough staked funds
- `amount` must be greater than zero
- `.call` must not revert

***

### `doLock(address user, uint256 amount)`

Locks funds for selling purposes. Funds remain locked until the sale is completed

**Parameters:** 
- `user`: Address of the user selling the item
- `amount`: Amount of funds to lock

**Requirements:**  
- Caller must be the shop   
- User must have enough staked funds
- `amount` must be greater than zero

***

### `doUnlock(address user, uint256 amount)`

Unlocks funds after the sale is completed

**Parameters:** 
- `user`: Address of the user
- `amount`: Amount of funds to unlock

**Requirements:**  
- Caller must be the shop   
- User must have enough locked funds
- `amount` must be greater than zero

***

### `doSlash(address badUser)`

Slashes funds if the user is considered malicious by the DAO

**Parameters:** 
- `badUser`: Address of the malicious user to be slashed

**Requirements:**  
- Caller must be the shop   

***

### `claimRewards()`

Claims rewards generated by slashing malicious users

**Requirements:**  
- User must have privileges determined by the powerseller contract
- User must not have already claimed the maximum amount of rewards

***

### `vaultBalance()`

Returns the balance of the vault

***

### `userBalance(address user)`

Returns the staked balance of a specific user

**Parameters:** 
- `user`: Address of the user to query

***

### `userLockedBalance(address user)`

Returns the locked balance of a specific user

**Parameters:** 
- `user`: Address of the user to query

***

### Internal Functions

#### `_distributeSlashing(uint256 amount)`

Distributes the slashing amount among the total powersellers to update the maximum claimable amount

**Parameters:** 
- `amount`: Amount of funds slashed

**Requirements:** 
- `totalPowerseller` low-level call must not revert

***

#### `_updateMaxClaimableAmount(uint256 totalPowersellers)`

Updates the maximum claimable amount per user based on the total slashed amount and the total number of powersellers

**Parameters:** 
- `totalPowersellers`: Total number of powersellers


***

# FP_Proxy Contract Documentation 🔄📜

## Description
The `FP_Proxy` 🔄 contract implements an upgradeable proxy pattern using EIP-1967. It allows for the upgrade of the contract implementation while preserving the storage layout defined in the proxy contract itself. This contract also includes role-based access control functionality

## Dependencies 🔗
- `ERC1967Utils` from OpenZeppelin: Utility functions for managing upgrades using EIP-1967

## Inheritance 🧬
- `ERC1967Proxy` from OpenZeppelin: Implements the EIP-1967 upgradeable proxy pattern

## Immutables
- `DAO_ADDRESS`: Role ID for the DAO role within the AccessControl contract

## Functions 🛠️

### `constructor(address implementation, bytes memory _data, address _dao)`

Initializes the proxy with an initial implementation and data for initialization

**Parameters:** 
- `implementation`: Address of the initial implementation contract
- `_data`: Data to be used for initialization
- `_dao`: Address of the DAO contract to grant initial permissions

**Requirements:**  
- If `data` is empty, `msg.value` must be zero

***

### `upgradeToAndCall(address _newImplementation, bytes memory _data)`

Upgrades the proxy to a new implementation and calls a function on the new implementation if `_data` is provided

**Parameters:** 
- `_newImplementation`: Address of the new implementation contract
- `_data`: Data to be used for initialization of the new implementation

**Requirements:**  
- The caller must be the DAO

***

### `getImplementation()`

Returns the current implementation address of the proxy

***

# FP_CoolNFT Contract Documentation 🆒📜

## Description
The `FP_CoolNFT` 🆒 contract implements an ERC721 token representing a Cool NFT that can be minted by the DAO and assigned to users. This contract restricts transfer and approval functionalities to maintain the uniqueness and control over the NFTs

## Inheritance 🧬
- `IFP_CoolNFT`: Interface for the FP_CoolNFT contract
- `ERC721` from OpenZeppelin: Implements the ERC721 standard for non-fungible tokens
- `AccessControl` from OpenZeppelin: Provides role-based access control for contract functions

## Constants 🔢
- `CONTROL_ROLE`: Role ID for controlling access to functions within the contract - (keccak256("CONTROL_ROLE"))
- `SHOP_ROLE`: Role ID for the shop address - (keccak256("SHOP_ROLE"))

## State Variables 📂
- `_daoSet`: Boolean flag to check if the DAO address has been set
- `_shopSet`: Boolean flag to check if the Shop address has been set
- `nextTokenId`: Tracks the ID of the next NFT to be minted
- `tokenIds`: Mapping from user address to their assigned NFT token IDs

## Events 📢
- `CoolNFTs_Slashed(address indexed owner)`: Emitted when a user's coolNFTs are slashed
- `CoolNFT_Removed(address indexed owner, uint256 tokenId)`: Emitted when a user loses their Cool NFT

## Modifiers
- `daoNotSet()`: Ensures that the DAO address has not been set before executing certain functions
- `shopNotSet()`: Ensures that the Shop address has not been set before executing certain functions

## Functions 🛠️

### `constructor()`

Initializes the contract by setting the name and symbol of the ERC721 token and granting the `CONTROL_ROLE` to the deploying address

***

### `setDAO(address daoAddr)`

Sets the DAO address and grants it the `CONTROL_ROLE`

**Parameters:** 
- `daoAddr`: Address of the DAO contract

**Requirements:**  
- The caller must be the deployer
- It can only be called once

***

### `setShop(address shopAddr)`

Sets the Shop address and grants it the `SHOP_ROLE`

**Parameters:** 
- `shopAddr`: Address of the Shop contract

**Requirements:**  
- The caller must be the deployer
- It can only be called once

***

### `mintCoolNFT(address to)`

Mints a Cool NFT for the specified user

**Parameters:** 
- `to`: Address of the user receiving the Cool NFT

**Requirements:**  
- The caller must be the DAO

***

### `burnAll(address owner)`

Removes the Cool NFTs from the specified user

**Parameters:** 
- `owner`: Address of the user losing their Cool NFTs

**Requirements:**  
- Caller must be the Shop

***

### `approve(address to, uint256 tokenId)`
### `setApprovalForAll(address operator, bool approved)`
### `transferFrom(address from, address to, uint256 tokenId)`
### `safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)`

ERC721 standard functions are overridden to revert transfers and approvals since Cool NFTs cannot be transferred

**Parameters:** 
- Parameters as per ERC721 standard

**Notes:** 
- These functions revert with a message indicating that Cool NFTs cannot be transferred

***

# FP_PowersellerNFT Contract Documentation 🏅📜

## Description
The `FP_PowersellerNFT` 🏅 contract implements an ERC721 token representing a PowerSeller NFT that can be minted by the shop and assigned to users. This contract restricts transfer and approval functionalities to maintain the uniqueness and control over the PowerSeller NFTs

## Inheritance 🧬
- `IFP_PowersellerNFT`: Interface for the FP_PowersellerNFT contract
- `ERC721` from OpenZeppelin: Implements the ERC721 standard for non-fungible tokens
- `AccessControl` from OpenZeppelin: Provides role-based access control for contract functions

## Constants 🔢
- `CONTROL_ROLE`: Role ID for controlling access to functions within the contract - (keccak256("CONTROL_ROLE"))

## State Variables 📂
- `_shopSet`: Boolean flag to check if the shop address has been set
- `nextTokenId`: Tracks the ID of the next NFT to be minted
- `_totalPowersellers`: Total count of users that have received a PowerSeller NFT
- `tokenIds`: Mapping from user address to their assigned PowerSeller NFT token ID

## Events 📢
- `PowersellerNFT_Minted(address indexed owner, uint256 tokenId)`: Emitted when a PowerSeller NFT is minted for a user
- `PowersellerNFT_Removed(address indexed owner, uint256 tokenId)`: Emitted when a user loses their PowerSeller NFT

## Modifiers
- `shopNotSet()`: Ensures that the shop address has not been set before executing certain functions

## Functions 🛠️

### `constructor()`

Initializes the contract by setting the name and symbol of the ERC721 token and granting the `CONTROL_ROLE` to the deploying address

***

### `setShop(address shopAddress)`

Sets the shop address and assigns it the `CONTROL_ROLE`

**Parameters:** 
- `shopAddress`: Address of the shop contract

**Requirements:**  
- The caller must be the deployer
- It can only be called once

***

### `safeMint(address to)`

Mints a PowerSeller NFT for the specified user

**Parameters:** 
- `to`: Address of the user receiving the PowerSeller NFT

**Requirements:**  
- The caller must be the shop
- User must not already have a PowerSeller NFT

***

### `removePowersellerNFT(address user)`

Removes the PowerSeller NFT from the specified user

**Parameters:** 
- `user`: Address of the user losing their PowerSeller NFT

**Requirements:**  
- The caller must be the shop
- User must have a PowerSeller NFT

***

### `totalPowersellers()`

Returns the total number of users that have received a PowerSeller NFT

***

### `checkPrivilege(address user)`

Checks if the specified user holds a PowerSeller NFT

**Parameters:** 
- `user`: Address of the user to check

***

### `approve(address to, uint256 tokenId)`
### `setApprovalForAll(address operator, bool approved)`
### `transferFrom(address from, address to, uint256 tokenId)`
### `safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)`

ERC721 standard functions are overridden to revert transfers and approvals since Powerseller NFTs cannot be transferred

**Parameters:** 
- Parameters as per ERC721 standard

**Notes:** 
- These functions revert with a message indicating that PowerSeller NFTs cannot be transferred

***

# FP_Token Contract Documentation 🪙📜

## Description
The `FP_Token` 🪙 contract is an ERC20 token implementation designed for governance within the Faillapop ecosystem. It includes roles for pausing operations, minting new tokens, and burning tokens

## Inheritance 🧬
- `AccessControl` from OpenZeppelin: Provides a way to control access to functions based on roles
- `ERC20` from OpenZeppelin: Implements the ERC20 token standard
- `ERC20Burnable` from OpenZeppelin: Extends ERC20 with burning capabilities
- `Pausable` from OpenZeppelin: Allows the contract to be paused and unpaused

## Constants 🔢
- `PAUSER_ROLE`: Role identifier for pausing contract operations - (keccak256("PAUSER_ROLE"))
- `MINTER_ROLE`: Role identifier for minting new tokens - (keccak256("MINTER_ROLE"))

## Functions 🛠️

### `constructor()`

Initializes the contract with the initial supply of FPT tokens and grants administrative and operational roles

***

### `pause()`

Pauses the contract operations

**Requirements:**  
- Caller must have the `PAUSER_ROLE`

***

### `unpause()`

Unpauses the contract operations

**Requirements:**  
- Caller must have the `PAUSER_ROLE`

***

### `mint(address to, uint256 amount)`

Mints new FPT tokens and assigns them to the specified address

**Parameters:** 
- `to`: Address to which the new tokens will be minted
- `amount`: Amount of tokens to mint

**Requirements:**  
- Caller must have the `MINTER_ROLE`

***
