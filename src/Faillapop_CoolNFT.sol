// SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.13;

import {IFP_CoolNFT} from "./interfaces/IFP_CoolNFT.sol";
import {AccessControl} from "@openzeppelin/contracts@v5.0.1/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts@v5.0.1/token/ERC721/ERC721.sol";

/** 
    @title Interface of the FaillaPop Cool NFT
    @author Faillapop team :D 
    @notice The contract allows the DAO to mint Cool NFTs for users.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract FP_CoolNFT is IFP_CoolNFT, ERC721, AccessControl {

    /************************************** Constants ****************************************************************/

    ///@notice The Control Role ID for the AccessControl contract. At first it's the msg.sender and then the DAO.
    bytes32 public constant CONTROL_ROLE = keccak256("CONTROL_ROLE");
    ///@notice The Shop Role ID for the AccessControl contract. At first it's the msg.sender and then the shop.
    bytes32 public constant SHOP_ROLE = keccak256("SHOP_ROLE");
    
    /************************************** State vars  ****************************************************************/ 

    ///@notice Bool to check if the DAO address has been set
    bool private _daoSet = false;
    ///@notice Bool to check if the shop address has been set
    bool private _shopSet = false;
    ///@notice The next tokenId to be minted
    uint256 public nextTokenId;
    ///@notice Mapping from user address to tokenId
    mapping (address => uint256[]) public tokenIds;

     /************************************** Modifiers *****************************************************/

    /**
        @notice Modifier to check if the DAO address has been set
     */
    modifier daoNotSet() {
        require(!_daoSet, "DAO address already set");
        _;
    }

    /**
        @notice Modifier to check if the Shop address has been set
     */
    modifier shopNotSet() {
        require(!_shopSet, "Shop address already set");
        _;
    }

    /************************************** External  ****************************************************************/ 

    /**
        @notice Constructor, initializes the contract
    */
    constructor() ERC721("Faillapop Cool NFT", "FCNFT") {
        _grantRole(CONTROL_ROLE, msg.sender);
    }

    /**
        @notice Sets the DAO address as the new Control Role
        @param daoAddr The address of the DAO contract
    */
    function setDAO(address daoAddr) external onlyRole(CONTROL_ROLE) daoNotSet {
        _daoSet = true;
        _grantRole(CONTROL_ROLE, daoAddr);
    }

    /**
        @notice Sets the shop address as the SHOP_ROLE
        @param shopAddress The address of the shop contract
    */
    function setShop(address shopAddress) external onlyRole(CONTROL_ROLE) shopNotSet {
        _shopSet = true;
        _grantRole(SHOP_ROLE, shopAddress);
    }

    /**
        @notice Mints a Cool NFT for the user
        @param to The address of the user that will receive the Cool NFT
    */
    function mintCoolNFT(address to) external onlyRole(CONTROL_ROLE) {
        nextTokenId++;
        tokenIds[to].push(nextTokenId);
        _safeMint(to, nextTokenId);
        
        emit CoolNFT_Minted(to, nextTokenId);
    }

    /**
        @notice Shop can remove all the Cool NFTs from a user
        @param owner The address of the user that will lose his Cool NFTs
    */
    function burnAll(address owner) external onlyRole(SHOP_ROLE) {
        if(tokenIds[owner].length > 0){
            uint256[] memory userTokens = tokenIds[owner];
            for (uint256 i = 0; i < userTokens.length; i++) { 
                _burn(userTokens[i]);
            }
            tokenIds[owner] = new uint256[](0);
            emit CoolNFTs_Slashed(owner);
        }
    }

    function getTokenIds(address owner) external view returns(uint256[] memory){
        return tokenIds[owner];
    }

    /************************************** Public  ****************************************************************/
    
    /**
     * @notice Cool NFTs cannot be transferred, so this function is overriden to revert
     */
    function approve(address /*to*/, uint256 /*tokenId*/) public virtual override{
        revert("CoolNFT cannot be approved");
    }

    /**
     * @notice Cool NFTs cannot be transferred, so this function is overriden to revert
     */
    function setApprovalForAll(address /*operator*/, bool /*approved*/) public virtual override{
        revert("CoolNFT cannot be approved");
    }

    /**
     * @notice Cool NFTs cannot be transferred, so this function is overriden to revert
     */
    function transferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) public virtual override{
        revert("CoolNFT cannot be transferred");
    }

    /**
     * @notice Cool NFTs cannot be transferred, so this function is overriden to revert
     */
    function safeTransferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/, bytes memory /*data*/) public virtual override{
        revert("CoolNFT cannot be transferred");
    }

    /**
        @notice Returns the supported interfaces collection
        @param interfaceId The interface identifier
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
}