// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/*
* @dev This contract includes an example of an integer underflow in line 31.
*/

contract BasicOverflow {
	uint8 public number = 255;
	
	function increment() public {
		number++;
	}

	function resetToMax() public {
		number = 255;
	}
}

contract Example5 {
    mapping (address => uint256) balance;
	mapping (address => uint256) timestamp;
	
    function deposit() external payable {
        balance[msg.sender] += msg.value;
		timestamp[msg.sender] = block.timestamp;
    }
	
	function withdraw() external {
		// Check
		require(timestamp[msg.sender] - block.timestamp > 300, 
			"A cooldown of 300 seconds is required!");
		// Effect
		uint toWithdraw = balance[msg.sender];
		balance[msg.sender] = 0;
		// Interaction
		(bool success, ) = payable(msg.sender).call{value: toWithdraw}("");
		require(sucess, "Low level call failed");
	}

}

