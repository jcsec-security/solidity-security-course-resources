// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IFP_DAO} from "./interfaces/IFP_DAO.sol";
import {IFP_CoolNFT} from "./interfaces/IFP_CoolNFT.sol";
import {IFP_Shop} from "./interfaces/IFP_Shop.sol";
import {AccessControl} from "@openzeppelin/contracts@v5.0.1/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts@v5.0.1/token/ERC20/IERC20.sol";


/** 
    @title FaillaPop voting DAO [v.02]
    @author Faillapop team :D 
    @notice The contract allows to vote with FPT tokens on open disputes. If the dispute is resolved in favor of the buyer,
        the seller have to refund the buyer. If the dispute is resolved in favor of the seller, the sale is closed.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract FP_DAO is IFP_DAO, AccessControl {
    
    /************************************** Enums & Structs *******************************************************/

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

    /************************************** Constants *******************************************************/

    ///@notice The threshold for the random number generator
    uint256 public constant THRESHOLD = 10;
    ///@notice The default number of voters for passing a dispute vote
    uint256 public constant DEFAULT_DISPUTE_QUORUM = 100;
    ///@notice the minimum committing period for votes on a dispute
    uint256 constant COMMITTING_TIME = 3 days;
    ///@notice The minimum revealing period for votes on a dispute
    uint256 constant MIN_REVEALING_TIME = 1 days;
    ///@notice The maximum revealing period for votes on a dispute
    uint256 constant MAX_REVEALING_TIME = 3 days;
    ///@notice The default number of voters for passing an update vote
    uint256 public constant DEFAULT_PROPOSAL_QUORUM = 500;
    ///@notice The time window in which a proposal can not be voted
    uint256 public constant PROPOSAL_REVIEW_TIME = 1 days;
    ///@notice The minimum voting period for a proposal
    uint256 public constant PROPOSAL_VOTING_TIME = 3 days;
    ///@notice The minimum waiting time between approval and execution of a proposal
    uint256 public constant PROPOSAL_EXECUTION_DELAY = 1 days;
    ///@notice The Control role ID for the AccessControl contract. At first it's the msg.sender and then the shop.
    bytes32 public constant CONTROL_ROLE = keccak256("CONTROL_ROLE");

    /************************************** Immutables *******************************************************/

    ///@notice The CoolNFT contract
    IFP_CoolNFT public immutable COOL_NFT_CONTRACT;
    ///@notice The FPT token contract
    IERC20 public immutable FPT_CONTRACT;

    /************************************** State vars *******************************************************/
    
    ///@notice Bool to check if the shop address has been set
    bool private _shopSet = false;

    ///@notice Current disputes, indexed by disputeId
    mapping(uint256 => Dispute) public disputes;
    ///@notice The ID of the next dispute to be created
    uint256 public nextDisputeId;
    ///@dev Mapping between disputeId and user address to record the hash of the vote + secret
    mapping(uint256 => mapping(address => bytes32)) public commitsOnDisputes;
    ///@dev Mapping between user address and disputeId to record the vote.
    mapping(address => mapping(uint256 => Vote)) public hasVotedOnDispute;
    ///@dev Mapping between disputeId and the result of the dispute.
    mapping(uint256 => Vote) public disputeResult;
    ///@dev Mapping between user address and disputeId to record the lottery check.
    mapping(address => mapping(uint256 => bool)) public hasCheckedLottery;
    ///@notice Min number of people to pass a dispute
    uint256 public disputeQuorum;

    ///@notice Current upgrade proposals, indexed by upgradeProposalId
    mapping(uint256 => UpgradeProposal) public upgradeProposals;
    ///@notice The ID of the next upgrade proposal to be created
    uint256 public nextUpgradeProposalId;
    ///@dev Mapping between user address and upgradeProposalId to record the vote
    mapping(address => mapping(uint256 => Vote)) public hasVotedOnUpgradeProposal;
    ///@dev Mapping between upgradeProposalId and the result of the proposal.
    mapping(uint256 => Vote) public upgradeProposalResult;
    ///@notice Min number of people to pass a proposal
    uint256 public proposalQuorum = DEFAULT_PROPOSAL_QUORUM; 

    ///@notice _password to access key features
    string private _password;
    ///@notice The address of the Shop contract
    address public shopAddress;


    /*************************************** Errors *******************************************************/

    ///@notice Throwed if a zero address (0x0) is detected in an operation that does not permit it
    error ZeroAddress();


    /************************************** Events and modifiers *****************************************************/

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


    /**
        @notice Check if the caller is authorized to access key features
        @param magicWord The password to access key features
     */
    modifier isAuthorized(string calldata magicWord) {
        require(
            keccak256(abi.encodePacked(magicWord)) == keccak256(abi.encodePacked(_password)),
            "Unauthorized");
        _;
    }


    /**
        @notice Modifier to check if the Shop address has been set
     */
    modifier shopNotSet() {
        require(!_shopSet, "Shop address already set");
        _;
    }

    /**
        @notice Check if the address is not zero
        @param toCheck The address to be checked
     */
    modifier notZero(address toCheck) {
        assembly {
            if iszero(toCheck) {
                let ptr := mload(0x40)
                mstore(ptr, 0xd92e233d00000000000000000000000000000000000000000000000000000000) // selector for error `ZeroAddress()`
                revert(ptr, 0x4)
            }
        }
        _;
    }

    /**
        @notice Check if the caller has already checked the lottery for a dispute
        @param user Caller's address
        @param disputeId Id of the dispute
     */
    modifier notChecked(address user, uint256 disputeId) {
        require(
            !hasCheckedLottery[user][disputeId],
            "User cannot check the lottery more than 1 time per dispute");
        _;
    }


    /************************************** External  ****************************************************************/ 
    
    /**
        @notice Constructor to set the password
        @param magicWord The password to access key features
        @param nftAddress The address of the NFT contract
        @param fptAddress The address of the FPT token
     */
    constructor(string memory magicWord, address nftAddress, address fptAddress) {
        _password = magicWord;
        _grantRole(CONTROL_ROLE, msg.sender);
        COOL_NFT_CONTRACT = IFP_CoolNFT(nftAddress);
        FPT_CONTRACT = IERC20(fptAddress);
    }

    /**
        @notice Sets the shop address as the new Control role
        @param shop The address of the shop 
    */
    function setShop(address shop) external onlyRole(CONTROL_ROLE) shopNotSet {
        _shopSet = true;
        shopAddress = shop;
        _grantRole(CONTROL_ROLE, shopAddress);
    }

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
    ) external onlyRole(CONTROL_ROLE) returns (uint256) {   
        uint256 dId = nextDisputeId;
        nextDisputeId += 1;

        disputes[dId] = Dispute(
            itemId,
            buyerReasoning,
            sellerReasoning,
            0,
            0,
            0,
            block.timestamp,
            0,
            DisputeState.COMMITTING_PHASE
        );  

        emit NewDispute(dId, itemId);
        return dId;
    }    

    /**
        @notice Commit the hash of the vote
        @param disputeId The ID of the target dispute
        @param commit Vote + secret hash
     */
    function commitVoteOnDispute(uint256 disputeId, bytes32 commit) external { 
        require(disputes[disputeId].state == DisputeState.COMMITTING_PHASE, "Dispute is not in committing phase");
        require(hasVotedOnDispute[msg.sender][disputeId] == Vote.DIDNT_VOTE , "You have already voted");        

        hasVotedOnDispute[msg.sender][disputeId] = Vote.COMMITTED;
        commitsOnDisputes[disputeId][msg.sender] = commit;

        emit DisputeVoteCommitted(disputeId, msg.sender);
    }

    /**
        @notice Reveal a vote on a dispute if commiting time has elapsed
        @param disputeId The ID of the target dispute
        @param vote The vote of the user
        @param secret The secret used to commit the vote
     */
    function revealDisputeVote(uint disputeId, bool vote, string calldata secret) external {
        if(disputes[disputeId].state != DisputeState.REVEALING_PHASE) {
            if(disputes[disputeId].state == DisputeState.COMMITTING_PHASE && disputes[disputeId].committingStartingTime + COMMITTING_TIME <= block.timestamp) {
                disputes[disputeId].state = DisputeState.REVEALING_PHASE;
                disputes[disputeId].revealingStartingTime = block.timestamp;
            } else {
                revert("Conditions for advancing to revealing phase are not met");
            }
        }        
        require(hasVotedOnDispute[msg.sender][disputeId] == Vote.COMMITTED, "You currently have no vote to reveal");

        bytes32 voteHash = keccak256(abi.encodePacked(vote, secret));
        require(commitsOnDisputes[disputeId][msg.sender] == voteHash, "Invalid vote hash");

        uint votingPower = _calcVotingPower(msg.sender);
        disputes[disputeId].totalVoters += 1;

        if (vote) {
            disputes[disputeId].votesFor += votingPower;
            hasVotedOnDispute[msg.sender][disputeId] = Vote.FOR;
        } else {
            disputes[disputeId].votesAgainst += votingPower;
        }

        emit DisputeVoteCasted(disputeId, msg.sender);
    }

    /**
        @notice Resolve a dispute if MIN_REVEALING_TIME has elapsed and if enough users have voted or MAX_REVEALING_TIME has elapsed. Then remove it from the storage
        @param disputeId The ID of the target dispute
     */
    function endDispute(uint256 disputeId) external { 
        require(disputes[disputeId].state == DisputeState.REVEALING_PHASE, "Dispute is not in revealing phase");
        require(disputes[disputeId].revealingStartingTime + MIN_REVEALING_TIME <= block.timestamp, "Minimum revealing time hasn't elapsed");
        require((disputes[disputeId].totalVoters > disputeQuorum) || (disputes[disputeId].revealingStartingTime + MAX_REVEALING_TIME <= block.timestamp), "Conditions for ending dispute are not met");

        uint256 itemId = disputes[disputeId].itemId;

        if (disputes[disputeId].votesFor > disputes[disputeId].votesAgainst) {
            delete disputes[disputeId];
            disputeResult[disputeId] = Vote.FOR;
            _buyerWins(itemId);
        } else {
            delete disputes[disputeId];
            disputeResult[disputeId] = Vote.AGAINST;
            _sellerWins(itemId);
        }

        emit EndDispute(disputeId, itemId);
    }   


    /**
        @notice Cancel an ongoing dispute. Either by the buyer or blacklisting (shop contract)
        @param disputeId The ID of the target dispute
     */
    function cancelDispute(uint256 disputeId) external onlyRole(CONTROL_ROLE) { 
        uint256 itemId = disputes[disputeId].itemId;     
                
        delete disputes[disputeId];

        emit EndDispute(disputeId, itemId);
    }   


    /**
        @notice Randomly award an NFT to a user if they voten for the winning side
        @param disputeId The ID of the target dispute
     */
    function checkLottery(uint256 disputeId) external notChecked(msg.sender, disputeId) { 
        require(hasVotedOnDispute[msg.sender][disputeId] != Vote.DIDNT_VOTE, "User didn't vote");
        hasCheckedLottery[msg.sender][disputeId] = true;
        if(disputeResult[disputeId] == hasVotedOnDispute[msg.sender][disputeId]) {
            _lotteryNFT(msg.sender);
        } else {
            revert("User voted for the wrong side");
        }
    }     

    /**
        @notice Open an upgrade proposal
        @param addrNewShop The address of the new Shop contract proposed
     */
    function newUpgradeProposal( 
        address addrNewShop
    ) external notZero(addrNewShop) returns (uint256) { 
        require(addrNewShop.code.length > 0, "The new shop address is invalid");      
        uint256 pId = nextUpgradeProposalId;
        nextUpgradeProposalId += 1;

        upgradeProposals[pId] = UpgradeProposal(
            msg.sender,
            pId,
            block.timestamp,
            0,
            addrNewShop,
            0,
            0,
            0,
            ProposalState.ACTIVE
        );  

        emit NewUpgradeProposal(pId, block.timestamp, addrNewShop);
        return pId;
    } 

    /**
        @notice Cast a vote on an upgrade proposal
        @param proposalId The ID of the upgrade proposal
        @param vote The vote, true for FOR, false for AGAINST
     */
    function castVoteOnProposal(uint256 proposalId, bool vote) external { 
        require(upgradeProposals[proposalId].state == ProposalState.ACTIVE , "Proposal is not active");
        require(upgradeProposals[proposalId].creationTimestamp + PROPOSAL_REVIEW_TIME < block.timestamp, "Proposal is not ready to be voted");
        
        require(hasVotedOnUpgradeProposal[msg.sender][proposalId] == Vote.DIDNT_VOTE , "You have already voted");
        
        uint256 votingPower = _calcVotingPower(msg.sender);
        require(votingPower > 0, "You have no voting power");

        if (vote) {
            upgradeProposals[proposalId].votesFor += votingPower;
            hasVotedOnUpgradeProposal[msg.sender][proposalId] = Vote.FOR;
        } else {
            upgradeProposals[proposalId].votesAgainst += votingPower;
            hasVotedOnUpgradeProposal[msg.sender][proposalId] = Vote.AGAINST; 
        }      

        upgradeProposals[proposalId].totalVoters += 1;

        emit ProposalVoteCasted(proposalId, msg.sender);
    }

    /**
        @notice Cancel an ongoing upgrade proposal by the proposal creator
        @param proposalId The ID of the upgrade proposal
     */
    function cancelProposalByCreator(uint256 proposalId) external {  
        require(upgradeProposals[proposalId].state == ProposalState.ACTIVE, "Proposal is not active");
        require(upgradeProposals[proposalId].creator == msg.sender, "You are not the creator of the proposal");
        _cancelProposal(proposalId);
    }  

    /**
        @notice Cancel an ongoing upgrade proposal by the admin of the DAO (who knows the password)
        @param proposalId The ID of the upgrade proposal
        @param magicWord The password to access key features
     */
    function cancelProposal(uint256 proposalId, string calldata magicWord) external isAuthorized(magicWord) {
        require(upgradeProposals[proposalId].state == ProposalState.ACTIVE, "Proposal is not active");
        _cancelProposal(proposalId);
    }    

    /**
        @notice Resolve a proposal if enough users have voted and enough time has passed
        @param proposalId The ID of the upgrade proposal
     */
    function resolveUpgradeProposal(uint256 proposalId) external { 
        require(upgradeProposals[proposalId].state == ProposalState.ACTIVE, "Proposal is not active"); 
        require(upgradeProposals[proposalId].creationTimestamp + PROPOSAL_VOTING_TIME < block.timestamp, "Proposal is not ready to be resolved");
        require(upgradeProposals[proposalId].totalVoters > proposalQuorum, "Not enough voters"); 
        address newShop = upgradeProposals[proposalId].newShop;
        if (upgradeProposals[proposalId].votesFor > upgradeProposals[proposalId].votesAgainst) {
            upgradeProposalResult[proposalId] = Vote.FOR;
            upgradeProposals[proposalId].state = ProposalState.PASSED;
            upgradeProposals[proposalId].approvalTimestamp = block.timestamp;
            emit ProposalPassed(proposalId, newShop, block.timestamp);
        } else {
            delete upgradeProposals[proposalId];
            upgradeProposalResult[proposalId] = Vote.AGAINST;
            emit ProposalNotPassed(proposalId, newShop);
        }
    }  

    /**
        @notice Execute a passed proposal
        @param proposalId The ID of the upgrade proposal
     */
    function executePassedProposal(uint256 proposalId) external { 
        require(upgradeProposals[proposalId].state == ProposalState.PASSED, "Proposal is not passed");    
        require(upgradeProposals[proposalId].approvalTimestamp + PROPOSAL_EXECUTION_DELAY < block.timestamp, "Proposal is not ready to be executed");
        address newShop = upgradeProposals[proposalId].newShop;    
        delete upgradeProposals[proposalId];

        (bool success, ) = shopAddress.call(
            abi.encodeWithSignature(
                "upgradeToAndCall(address,bytes)",
                newShop,
                "" 
            )
        );

        require(success, "upgradeToAndCall(address,bytes) call failed");
        emit ProposalExecuted(proposalId, newShop);
    }

    /************************************** Views *********************************************************************/

    /**
        @notice Query the details of a dispute
        @param disputeId The ID of the target dispute
     */
	function queryDispute(uint256 disputeId) public view returns (Dispute memory) {
		return disputes[disputeId];
	}  

    /**
        @notice Query the result of a dispute
        @param disputeId The ID of the target dispute
     */
	function queryDisputeResult(uint256 disputeId) public view returns (Vote) {
		return disputeResult[disputeId];
	}  

    /**
        @notice Query the details of an upgrade proposal
        @param upgradeProposalId The ID of the target proposal
     */
	function queryUpgradeProposal(uint256 upgradeProposalId) public view returns (UpgradeProposal memory) {
		return upgradeProposals[upgradeProposalId];
	}

    /**
        @notice Query the result of an upgrade proposal
        @param upgradeProposalId The ID of the target proposal
     */
	function queryUpgradeProposalResult(uint256 upgradeProposalId) public view returns (Vote) {
		return upgradeProposalResult[upgradeProposalId];
	}  

    /************************************** Internal *****************************************************************/
    
    /**
        @notice Run a PRNG to award NFT to a user
        @param user The address of the elegible user
     */
    function _lotteryNFT(address user) internal { 
        uint256 randomNumber = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1), 
                        block.timestamp, 
                        user
        ))));

        if (randomNumber < THRESHOLD) {
            COOL_NFT_CONTRACT.mintCoolNFT(user);
        }

        emit AwardNFT(user);
    }

    /**
        @notice Resolve a dispute in favor of the buyer triggering the Shop's return item and refund logic
        @param itemId The ID of the item involved in the dispute
     */
    function _buyerWins(uint256 itemId) internal {
        (bool success, ) = shopAddress.call(
            abi.encodeWithSignature(
                "returnItem(uint256)",
                itemId
            )
        );
        require(success, "returnItem(uint256) call failed");
    }

    /**
        @notice Resolve a dispute in favor of the seller triggering the Shop's close sale dispute logic
        @param itemId The ID of the item involved in the dispute
     */
    function _sellerWins(uint256 itemId) internal {
        (bool success, ) = shopAddress.call(
            abi.encodeWithSignature(
                "endDispute(uint256)",
                itemId
            )
        );
        require(success, "endDispute(uint256) call failed");
    }

    /**
        @notice Calculate the voting power of a user
        @param user The address of the user to calculate the voting power
     */
    function _calcVotingPower(address user) internal view returns (uint256) {
        return FPT_CONTRACT.balanceOf(user);
    } 

    /**
        @notice Cancel an ongoing upgrade proposal. Either by the sender of the proposal or the admin (who knows the password)
        @param proposalId The ID of the upgrade proposal
     */
    function _cancelProposal(uint proposalId) internal {                 
        delete upgradeProposals[proposalId];

        emit ProposalCanceled(proposalId);
    } 

}