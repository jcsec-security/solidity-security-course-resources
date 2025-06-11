// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

/*
* Template ERC20 token for governance
*/

import {AccessControl} from "@openzeppelin/contracts@v5.0.1/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts@v5.0.1/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@v5.0.1/token/ERC20/extensions/ERC20Burnable.sol";
import {Pausable} from "@openzeppelin/contracts@v5.0.1/utils/Pausable.sol";

contract FP_Token is ERC20, ERC20Burnable, Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() ERC20("FaillaPop Token", "FPT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _mint(msg.sender, 1000000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

}