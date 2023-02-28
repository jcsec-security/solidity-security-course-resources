// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

/*
* @dev This contract includes an example of lack of access controls in line 30.
*/

contract Example6 is Ownable {
    mapping (address => uint256) balance;
    mapping (address => uint256) blockstamp;
	
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
	
	function resetTimestamp (address user) public {
		blockstamp[user] = 0;
	}
}

