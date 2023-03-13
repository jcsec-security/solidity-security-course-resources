// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "./interfaces/IFP_Shop.sol";
import "./interfaces/IFP_NFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/** 
    @title FaillaPop voting DAO [v.02]
    @author Faillapop team :D 
    @notice The contract allows to vote with FPT tokens on open disputes. If the dispute is resolved in favor of the buyer,
        the seller have to refund the buyer. If the dispute is resolved in favor of the seller, the sale is closed.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract FP_DAO {
    
        /************************************** Constants *******************************************************/
    ///@notice The threshold for the random number generator
    uint constant THRESHOLD = 10;
    ///@notice The default number of voters for passing a vote
    uint constant DEFAULT_QUORUM = 100;


    /************************************** State vars and Structs *******************************************************/
    
    /** 
        @notice A Dispute includes the itemId, the reasoning of the buyer and the seller on the claim,
        and the number of votes for and against the dispute.
        @dev A Dispute is always written from the POV of the buyer
            - FOR is in favor of the buyer claim
            - AGAINST is in favor of the seller claim
     */
    struct Dispute {
        uint itemId;
        string buyerReasoning;
        string sellerReasoning;
        uint votesFor;
        uint votesAgainst;
        uint totalVoters;
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


    ///@notice Current disputes, indexed by disputeId
    mapping(uint256 => Dispute) public disputes;
    ///@notice The ID of the next dispute to be created
    uint256 public nextDisputeId;
    ///@dev Mapping between user address and disputeId to record the vote.
    mapping(address => mapping(uint => Vote)) public hasVoted;
    ///@dev Mapping between disputeId and the result of the dispute.
    mapping(uint256 => Vote) public disputeResult;
    ///@notice Password to access key features
    string private password;
    ///@notice The address of the Shop contract
    address public shop_addr;
    ///@notice The Shop contract
    IFP_Shop public shopContract;
    ///@notice The NFT contract
    IFP_NFT public nftContract;
    ///@notice The FPT token contract
    IERC20 public fptContract;
    ///@notice Min number of people to pass a proposal
    uint256 quorum;


    /************************************** Events and modifiers *****************************************************/

    ///@notice Emitted when the contract configuration is changed, contains the address of the Shop
    event NewConfig(address shop, address nft);
    ///@notice Emitted when a user votes, contains the disputeId and the user address
    event VoteCasted(uint disputeId, address user);
    ///@notice Emitted when a new dispute is created, contains the disputeId and the itemId
    event NewDispute(uint disputeId, uint itemId);
    ///@notice Emitted when a dispute is closed, contains the disputeId and the itemId
    event EndDispute(uint disputeId, uint itemId);
    ///@notice Emitted when a user is awarder a cool NFT, contains the user address
    event AwardNFT(address user);


    /**
        @notice Check if the caller is authorized to access key features
        @param magicWord The password to access key features
     */
    modifier isAuthorized(string calldata magicWord) {
        require(
            keccak256(abi.encodePacked(magicWord)) == keccak256(abi.encodePacked(password)),
            "Unauthorized");
        _;
    }


    ///@notice Check if the caller is the Shop contract
    modifier onlyShop() {
		require(
            msg.sender == shop_addr,
            "Unauthorized"
        );
        _;
    }


    /************************************** External  ****************************************************************/ 
    
    /**
        @notice Constructor to set the password
        @param magicWord The password to access key features
        @param shop The address of the Shop contract
        @param nft_addr The address of the NFT contract
        @param fpt_addr The address of the FPT token
     */
    constructor(string memory magicWord, address shop, address nft_addr, address fpt_addr) {
        password = magicWord;
        shop_addr = shop;
        shopContract = IFP_Shop(shop_addr);
        nftContract = IFP_NFT(nft_addr);
        fptContract = IERC20(fpt_addr);
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
    ) external isAuthorized(magicWord) {
        password = newMagicWord;
        shop_addr = newShop;
        
        shopContract = IFP_Shop(shop_addr);
        nftContract = IFP_NFT(newNft);
        
        emit NewConfig(shop_addr, newNft);
    }

    /**
        @notice Cast a vote on a dispute
        @param disputeId The ID of the target dispute
        @param vote The vote, true for FOR, false for AGAINST
     */
    function castVote(uint disputeId, bool vote) external { 
        require(hasVoted[msg.sender][disputeId] == Vote.DIDNT_VOTE , "You have already voted");
        
        uint votingPower = calcVotingPower(msg.sender);

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
        uint itemId, 
        string calldata buyerReasoning, 
        string calldata sellerReasoning
    ) external onlyShop() returns (uint) {     
        uint dId = nextDisputeId;
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
    function endDispute(uint disputeId) external {  
        if (disputes[disputeId].totalVoters < quorum) {
            revert("Not enough voters");
        }

        uint itemId = disputes[disputeId].itemId;

        if (disputes[disputeId].votesFor > disputes[disputeId].votesAgainst) {
            buyerWins(itemId);
            disputeResult[disputeId] = Vote.FOR;
        } else {
            sellerWins(itemId);
            disputeResult[disputeId] = Vote.AGAINST;
        }
        
        delete disputes[disputeId];

        emit EndDispute(disputeId, itemId);
    }   


    /**
        @notice Cancel an ongoing dispute. Either by the buyer or blacklisting (shop contract)
        @param disputeId The ID of the target dispute
     */
    function cancelDispute(uint disputeId) external onlyShop() { 
        uint itemId = disputes[disputeId].itemId;     
                
        delete disputes[disputeId];

        emit EndDispute(disputeId, itemId);
    }   


    /**
        @notice Randomly award an NFT to a user if they voten for the winning side
        @param disputeId The ID of the target dispute
     */
    function checkLottery(uint disputeId) external { 
        require(hasVoted[msg.sender][disputeId] != Vote.DIDNT_VOTE, "User didn't vote");
        
        if(disputeResult[disputeId] == hasVoted[msg.sender][disputeId]) {
            lotteryNFT(msg.sender);
        } else {
            revert("User voted for the wrong side");
        }

    }        

    /************************************** Internal *****************************************************************/
    
    /**
        @notice Run a PRNG to award NFT to a user
        @param user The address of the elegible user
     */
    function lotteryNFT(address user) internal { 
        uint randomNumber = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1), 
                        block.timestamp, 
                        user
        ))));

        if (randomNumber < THRESHOLD) {
            nftContract.mintCoolNFT(user);
            
        }

        emit AwardNFT(user);  
    }

    /**
        @notice Resolve a dispute in favor of the buyer triggering the Shop's return item and refund logic
        @param itemId The ID of the item involved in the dispute
     */
    function buyerWins(uint itemId) internal {
        shopContract.returnItem(itemId);
    }

    /**
        @notice Resolve a dispute in favor of the seller triggering the Shop's close sale dispute logic
        @param itemId The ID of the item involved in the dispute
     */
    function sellerWins(uint itemId) internal {
        shopContract.endDispute(itemId);
    }

    /**
        @notice Calculate the voting power of a user
     */
    function calcVotingPower(address user) internal returns (uint256) {
        return fptContract.balanceOf(user);
    } 

    /************************************** Views *********************************************************************/

    /**
        @notice Query the details of a dispute
        @param disputeId The ID of the target dispute
     */
	function query_dispute(uint disputeId) public view returns (Dispute memory) {
		return disputes[disputeId];
	}


}