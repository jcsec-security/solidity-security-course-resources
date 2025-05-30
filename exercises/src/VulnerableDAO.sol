// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;


uint256 constant THRESHOLD = 10;

 
///@notice The contract allows to vote on open disputes. If the dispute is resolved in favor of the buyer,
/// the seller have to refund the buyer. If the dispute is resolved in favor of the seller, the sale is closed.
///@dev Security review is pending... should we deploy this?
///@custom:exercise This contract is part of the exercises at https://github.com/jcr-security/solidity-security-teaching-resources
contract VulnerableDAO {

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

    mapping(uint256 disputeId => Dispute) public disputes;
    // Password to access the key functions
    string private password;


    /************************************** Events and modifiers *****************************************************/

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

    /************************************** External  ****************************************************************/ 

    /**
        @notice Constructor to set the password
        @param magicWord The password to access key features
    */
    constructor(string memory magicWord) {
        password = magicWord;
    }


    /**
        @notice Update the contract's configuration details
        @param magicWord to authenticate as privileged user
        @param newMagicWord The new password to access key features
     */
    function updateConfig(
        string calldata magicWord, 
        string calldata newMagicWord 
    ) external isAuthorized(magicWord) {
        password = newMagicWord;

        /*
        * DAO configuration logic goes here.
        * Consider this missing piece of code to be correct, do not ponder
        * about potential lack of validtaion or checks here
        */

    }


    /**
        @notice Cast a vote on a dispute
        @param disputeId The ID of the target dispute
        @param vote The vote, true for FOR, false for AGAINST
     */
    function castVote(uint256 disputeId, bool vote) external {  

        /*
        * DAO vote casting logic goes here.
        * Consider this missing piece of code to be correct, do not ponder
        * about potential lack of validtaion or checks here
        */

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
        string calldata sellerReasoning,
        string calldata magicWord
    ) external isAuthorized(magicWord) returns (uint256) { 

        /*
        * DAO dispute logic goes here.
        * Consider this missing piece of code to be correct, do not ponder
        * about potential lack of validtaion or checks here
        */

    }    


    /**
        @notice Resolve a dispute if enough users have voted and remove it from the storage
        @param disputeId The ID of the target dispute
     */
    function endDispute(uint256 disputeId) external {  

        /*
        * DAO dispute logic goes here.
        * Consider this missing piece of code to be correct, do not ponder
        * about potential lack of validtaion or checks here
        */

    }    

    /**
        @notice Randomly award an NFT to a user if they voten for the winning side
        @param disputeID The ID of the target dispute
     */
    function checkLottery(uint256 disputeID) external {     
          
        /*
        * DAO lottery award logic goes here.
        * Consider this missing piece of code to be correct, do not ponder
        * about potential lack of validtaion or checks here
        */

        lotteryNFT(msg.sender);

    }      


    /************************************** Internal *****************************************************************/

    /**
        @notice Run a PRNG to award a cool NFT to the user
        @param user The address of the elegible user
     */
    function lotteryNFT(address user) internal {
        uint256 randomNumber = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        blockhash(block.number - 1), 
                        block.timestamp, 
                        user
        ))));

        if (randomNumber < THRESHOLD   ) {

            /*
            * Award NFT logic goes here.
            * Consider this missing piece of code to be correct, do not ponder
            * about potential lack of validtaion or checks here
            */
            
            emit AwardNFT(user);
        }

        
    }


    /************************************** Views ********************************************************************/

    /**
        @notice Query the details of a dispute
        @param disputeId The ID of the target dispute
     */
	function query_dispute(uint256 disputeId) public view returns (Dispute memory) {
		return disputes[disputeId];
	}

}