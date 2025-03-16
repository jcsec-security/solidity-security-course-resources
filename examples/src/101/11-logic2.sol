// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


/**
	@dev This contract includes an examples of a logic bug. Line 21 is incorrect, third term should be 16.
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract Example11 {

	// Incorrect math Implementación matemática incorrecta. Ej (a+b)^2 = A2 + 2ab + b2.
	constructor() {}

	// (2a + 3b)^2 
	function op1(uint256 a, uint256 b) external returns (uint256 res) {
		res = 4*a*a + 12*a*b + 9*b*b;
	}

	// (a - 4b)^2
	function op2(uint256 a, uint256 b) external returns (uint256 res) {
		res = a*a + 8*a*b + 15*b*b;
	}

	// (2a + b)^3 
	function op3(uint256 a, uint256 b) external returns (uint256 res) {
		res = 6*a*a*a + 12*a*a*b + 6*a*b*b + b*b*b;
	}

	// (5a - 10b)^3 
	function op4(uint256 a, uint256 b) external returns (uint256 res) {
		res = 125*a*a*a - 750*a*a*b + 15*100*a*b*b - 1000*b*b*b;
	}			

}
