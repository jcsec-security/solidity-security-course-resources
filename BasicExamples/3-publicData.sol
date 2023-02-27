// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @dev This contract includes an example of cleartext data treated as a secret.
*/ 
// Deployed in Goerli at 0xd7F07FA527C4eE13717125534A7258fFa60CE6c1

contract Example3 {
    uint256 public number;
    string private secret;

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

