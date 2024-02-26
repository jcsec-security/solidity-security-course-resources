// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
    @dev This contract includes an example of unchecked return statement on ERC20.
        You can read about unchecked return values at https://swcregistry.io/docs/SWC-104/
    @custom:deployed-at ETHERSCAN URL
	@custom:exercise This contract is part of JC's basic examples at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract BuyMeNFT is ERC721, ERC721Enumerable {

    IERC20 public immutable uma_tkn;
    uint256 private _nextTokenId;

    constructor(address tkn) ERC721("Vulnerable", "VNFT") {
        uma_tkn = IERC20(tkn);
    }

	function mint() external payable {
        // Requires 10 UMA tokens to mint an NFT
		uma_tkn.transferFrom(msg.sender, 10);

        uint256 tokenId = _nextTokenId++;		
		_safeMint(msg.sender, tokenId);
	}

    // Function override required by Solidity, don´t mind this for now
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    // Function override required by Solidity, don´t mind this for now
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    // Function override required by Solidity, don´t mind this for now
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
