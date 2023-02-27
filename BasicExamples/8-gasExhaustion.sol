// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @dev This contract includes an example of DoS by gas exhaustion due to an unbounded loop.
*/

contract Example8 {
address[] creditorAddresses;
address win;

    function emptyCreditors() public {
        for (uint i = 1; i < creditorAddresses.length; i++) {
            if (creditorAddresses[i-1] != creditorAddresses[i]) {
               win = creditorAddresses[i];
            }
        }
    }

    function addCreditors() external {
        for(uint i=0;i<350;i++) {
            creditorAddresses.push(msg.sender);
        }
    }

    function amIWinner() public view returns (bool) {
       return win == msg.sender;
    }
}

