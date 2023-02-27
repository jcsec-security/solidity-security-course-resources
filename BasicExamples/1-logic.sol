// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @dev This contract includes an examples of a logic bug. 
* @dev Line 27 updates the accumulator only when entering the if statement, instead of updating it at the end of the loop.
*/

import "@openzeppelin/contracts/access/Ownable.sol";

uint constant N_VAULT = 10;

struct Vault {
	bool locked;
	uint[] wallet;
}

contract Example1 is Ownable {
	Vault[N_VAULT] vaults;

    function checkCredit() external onlyOwner {
		uint accumulator = 0;
		for (uint i = 1; i < N_VAULT; i++) { 	
			for (uint j = 0; i< vaults[i].wallet.length; j++) {
				accumulator += vaults[i].wallet[j];
			}
			
			if (accumulator < 1000) {
				vaults[i].locked = true;
				accumulator = 0;
			}		
		}
    }
}
