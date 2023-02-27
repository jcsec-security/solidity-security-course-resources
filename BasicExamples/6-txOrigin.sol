// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

/*
* @dev This contract includes an example of lack of access controls in line 30.
*/

contract Example6 is Ownable {
    mapping (address => uint256) balance;
    mapping (address => uint256) timestamp;
	
    function deposit() external payable {
        balance[msg.sender] += msg.value;
		timestamp[msg.sender] = block.number;
    }
	
	function withdraw() external {		
		// Checks
		require(block.number - timestamp[msg.sender] > 5,
			"Tienes que esperar al menos 5 bloques!");
		// Effects	
		uint256 withdrawn = balance[msg.sender];
		balance[msg.sender] = 0;	
		// Interactions
		payable(msg.sender).call{value: withdrawn}("");
	}
	
	function resetTimestamp (address user) public {
		timestamp[user] = 0;
	}
}

