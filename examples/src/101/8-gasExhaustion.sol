// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


/**
    @dev This contract includes an example of DoS by gas exhaustion (OOG) due to an unbounded loop.
        You can read about Gas Exhaustion at https://swcregistry.io/docs/SWC-128
    @custom:deployed-at ETHERSCAN URL
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract Example8 {

    address[] creditorAddresses;
    address win;

    function checkCreditors() public {
        for (uint256 i = 1; i < creditorAddresses.length; i++) {
            if (creditorAddresses[i-1] != creditorAddresses[i]) {
               win = creditorAddresses[i];

            }
        }
    }

    function addCreditors() external {
        for(uint256 i=0;i<350;i++) {
            creditorAddresses.push(msg.sender);
        }
    }

    function amIWinner() public view returns (bool) {
       return win == msg.sender;
    }

}

