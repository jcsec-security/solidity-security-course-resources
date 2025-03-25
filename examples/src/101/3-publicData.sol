// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


/**
    @dev This contract includes an example of cleartext data considered a secret.
    @custom:deployed-at https://sepolia.etherscan.io/address/0xd312426bf550e4729808ced2b277e44c3ddc9b38
    		You can read about Unencrypted data on-chain at https://swcregistry.io/docs/SWC-136
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources    
*/ 
contract Example3 {

    uint256 public number;
    string private secret; // Making this private DOES NOT protect it from being read on-chain!
    address public winner;

    constructor(string memory _secret) {
        secret = _secret;
    }

    // This function performs a privileged action!
    // We only want specific individuals to be able to use it...
    function setNumber(uint256 newNumber, string memory password) public {
        require(
            keccak256(bytes(password)) == keccak256(bytes(secret)),
            "Unauthorized!"
        );
        
        number = newNumber;      
    }


    function increment() public {
        number++;
    }


    function isItFive() external {
        if (number == 5) {
            winner = msg.sender;
            number++;       
        }
    }

}

