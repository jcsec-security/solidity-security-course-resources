// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


/**
    @dev This contract includes an example of cleartext data considered a secret.
    @custom:deployed-at ETHERSCAN URL
    		You can read about Unencrypted data on-chain at https://swcregistry.io/docs/SWC-136
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources    
*/ 
contract Example3 {

    uint256 public number;
    string private secret; // Making this private DOES NOT protect it from being read on-chain!


    constructor(string memory _secret) {
        secret = _secret;
    }


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

}

