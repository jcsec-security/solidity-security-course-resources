// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


/**
	@dev This contract includes an example of bad AC relying on ts.origin, which opens
		a windows for phishing attack against the owner to bypass the AC.
	@custom:deployed-at ETHERSCAN URL
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract Example6_2 {

    mapping (address => uint256) balance;
    mapping (address => uint256) blockstamp;
	address owner;


	///@notice This modifier do not apply AC to the actual caller but to the origin of the transaction
	modifier onlyOwner() {
		require(tx.origin == owner, "Only owner can call this function.");
		_;
	}


	constructor() {
		owner = msg.sender;
	}
	

    function deposit() external payable {
        balance[msg.sender] += msg.value;
		blockstamp[msg.sender] = block.number;
    }
	

	function withdraw() external {		
		// Checks
		require(block.number - blockstamp[msg.sender] > 10,
			"A cooldown of 10 blocks is required!!");

		// Effects	
		uint256 withdrawn = balance[msg.sender];
		balance[msg.sender] = 0;	

		// Interactions
		(bool success, ) = payable(msg.sender).call{value: withdrawn}("");
		require(success, "Low level call failed");
	}

	
	function resetTimestamp (address user) public onlyOwner {
		blockstamp[user] = 0;
	}

}