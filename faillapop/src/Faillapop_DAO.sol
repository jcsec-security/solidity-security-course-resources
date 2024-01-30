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

        /*************************************** Errors *******************************************************/
    ///@notice Throwed if a zero address (0x0) is detected in an operation that does not permit it
    error ZeroAddress();
    
        /************************************** Constants *******************************************************/
    ///@notice The threshold for the random number generator
    uint256 public constant THRESHOLD = 10;
    ///@notice The default number of voters for passing a vote
    uint256 public constant DEFAULT_QUORUM = 100;


    /************************************** State vars and Structs *******************************************************/
    
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
    }


    /**
        @notice The Vote enum is used to record the vote of a user
        @dev DIDNT_VOTE is the default value, FOR and AGAINST are the possible votes
     */
    enum Vote {
        DIDNT_VOTE,
        FOR,
        AGAINST
    }

    ///@notice The Control role ID for the AccessControl contract. At first it's the msg.sender and then the shop.
    bytes32 public constant CONTROL_ROLE = keccak256("CONTROL_ROLE");
    ///@notice Bool to check if the shop address has been set
    bool private _shopSet = false;
    ///@notice Current disputes, indexed by disputeId
    mapping(uint256 => Dispute) public disputes;
    ///@notice The ID of the next dispute to be created
    uint256 public nextDisputeId;
    ///@dev Mapping between user address and disputeId to record the vote.
    mapping(address => mapping(uint256 => Vote)) public hasVoted;
    ///@dev Mapping between disputeId and the result of the dispute.
    mapping(uint256 => Vote) public disputeResult;
    ///@dev Mapping between user address and disputeId to record the lottery check.
    mapping(address => mapping(uint256 => bool)) public hasCheckedLottery;
    ///@notice _password to access key features
    string private _password;
    ///@notice The Shop contract
    IFP_Shop public shopContract;
    ///@notice The CoolNFT contract
    IFP_CoolNFT public coolNFTContract;
    ///@notice The FPT token contract
    IERC20 public immutable fptContract;
    ///@notice Min number of people to pass a proposal
    uint256 public quorum;


    /************************************** Events and modifiers *****************************************************/

    ///@notice Emitted when the contract configuration is changed, contains the address of the Shop
    event NewConfig(address shop, address nft);
    ///@notice Emitted when a user votes, contains the disputeId and the user address
    event VoteCasted(uint256 disputeId, address user);
    ///@notice Emitted when a new dispute is created, contains the disputeId and the itemId
    event NewDispute(uint256 disputeId, uint256 itemId);
    ///@notice Emitted when a dispute is closed, contains the disputeId and the itemId
    event EndDispute(uint256 disputeId, uint256 itemId);
    ///@notice Emitted when a user is awarder a cool NFT, contains the user address
    event AwardNFT(address user);


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
        coolNFTContract = IFP_CoolNFT(nftAddress);
        fptContract = IERC20(fptAddress);
    }

    /**
        @notice Sets the shop address as the new Control role
        @param shopAddress  The address of the shop 
    */
    function setShop(address shopAddress) external onlyRole(CONTROL_ROLE) shopNotSet {
        _shopSet = true;
        shopContract = IFP_Shop(shopAddress);
        _grantRole(CONTROL_ROLE, shopAddress);
    }

    /**
        @notice Update the contract's configuration details
        @param magicWord to authenticate as privileged user
        @param newMagicWord The new password to access key features
        @param newShop The new address of the Shop contract
        @param newNft The new address of the NFT contract
     */
    function updateConfig(
        string calldata magicWord, 
        string calldata newMagicWord, 
        address newShop,
        address newNft
    ) external isAuthorized(magicWord) notZero(newShop) notZero(newNft){ 
        _password = newMagicWord;
        
        shopContract = IFP_Shop(newShop);
        coolNFTContract = IFP_CoolNFT(newNft);
        
        emit NewConfig(newShop, newNft);
    }

    /**
        @notice Cast a vote on a dispute
        @param disputeId The ID of the target dispute
        @param vote The vote, true for FOR, false for AGAINST
     */
    function castVote(uint256 disputeId, bool vote) external { 
        require(hasVoted[msg.sender][disputeId] == Vote.DIDNT_VOTE , "You have already voted");
        
        uint256 votingPower = _calcVotingPower(msg.sender);
        require(votingPower > 0, "You have no voting power");

        if (vote) {
            disputes[disputeId].votesFor += votingPower;
            hasVoted[msg.sender][disputeId] = Vote.FOR;
        } else {
            disputes[disputeId].votesAgainst += votingPower;
            
        }      

        disputes[disputeId].totalVoters += 1;

        emit VoteCasted(disputeId, msg.sender);
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
            0
        );  

        emit NewDispute(dId, itemId);
        return dId;
    }    

    /**
        @notice Resolve a dispute if enough users have voted and remove it from the storage
        @param disputeId The ID of the target dispute
     */
    function endDispute(uint256 disputeId) external {  
        if (disputes[disputeId].totalVoters < quorum) {
            revert("Not enough voters");
        }

        uint256 itemId = disputes[disputeId].itemId;

        if (disputes[disputeId].votesFor > disputes[disputeId].votesAgainst) {
            delete disputes[disputeId];
            _buyerWins(itemId);
            disputeResult[disputeId] = Vote.FOR;
        } else {
            delete disputes[disputeId];
            _sellerWins(itemId);
            disputeResult[disputeId] = Vote.AGAINST;
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
        require(hasVoted[msg.sender][disputeId] != Vote.DIDNT_VOTE, "User didn't vote");
        hasCheckedLottery[msg.sender][disputeId] = true;
        if(disputeResult[disputeId] == hasVoted[msg.sender][disputeId]) {
            _lotteryNFT(msg.sender);
        } else {
            revert("User voted for the wrong side");
        }
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
	function queryDisputeResult(uint disputeId) public view returns (Vote) {
		return disputeResult[disputeId];
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
            coolNFTContract.mintCoolNFT(user);            
        }

        emit AwardNFT(user);  
    }

    /**
        @notice Resolve a dispute in favor of the buyer triggering the Shop's return item and refund logic
        @param itemId The ID of the item involved in the dispute
     */
    function _buyerWins(uint256 itemId) internal {
        shopContract.returnItem(itemId);
    }

    /**
        @notice Resolve a dispute in favor of the seller triggering the Shop's close sale dispute logic
        @param itemId The ID of the item involved in the dispute
     */
    function _sellerWins(uint256 itemId) internal {
        shopContract.endDispute(itemId);
    }

    /**
        @notice Calculate the voting power of a user
     */
    function _calcVotingPower(address user) internal view returns (uint256) {
        return fptContract.balanceOf(user);
    } 


}