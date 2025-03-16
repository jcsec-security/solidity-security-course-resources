// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


///@dev This contract includes an examples of a logic bug. Lines 27-30 increment the ID and mint a new token but never
/// reduces the adress' allowance.
///@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources
///@custom:crediting This idea was taken from an online challenge published by RareSkill
contract Example12 is ERC721, Ownable {

    uint256 id;
    mapping(address minter => uint256 n_tokens) public allowances;


    constructor() ERC721("Token Example3", "EX3") Ownable(msg.sender) {}


    function mint(uint256 amount) external {
        require(
            amount <= allowances[msg.sender],
            "Can't mint more than allowed"
        );

        for(uint256 i = 0; i < amount; i++) {
            id++;
            _safeMint(msg.sender, id);
        }
    }


    function newAllowances(
        address[] calldata minters, 
        uint256[] calldata amounts
    ) external onlyOwner {
        require(minters.length == amounts.length,
            "Lenght mismatch"
        );

        for(uint256 i = 0; i < minters.length; i++) {
            allowances[minters[i]] = amounts[i];
        }
    }

}
