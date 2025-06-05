// SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.13;

import {IFP_PowersellerNFT} from "./interfaces/IFP_PowersellerNFT.sol";
import {AccessControl} from "@openzeppelin/contracts@v5.0.1/access/AccessControl.sol";
import {ERC721} from "@openzeppelin/contracts@v5.0.1/token/ERC721/ERC721.sol";

/** 
    @title FaillaPop PowerSeller NFT [v0.1]
    @author Faillapop team :D 
    @notice The contract allows the shop to mint a PowerSeller NFT for users and remove it if they are considered malicious. PowerSeller badge is required to claimRewards in the vault.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/faillapop
*/
contract FP_PowersellerNFT is IFP_PowersellerNFT, ERC721, AccessControl {

    /************************************** Constants  ****************************************************************/

    ///@notice The Control role ID for the AccessControl contract. At first it's the msg.sender and then the shop.
    bytes32 public constant CONTROL_ROLE = keccak256("CONTROL_ROLE");

    /************************************** State vars  ****************************************************************/ 

    ///@notice Bool to check if the shop address has been set
    bool private _shopSet = false;
    ///@notice The next tokenId to be minted
    uint256 public nextTokenId;
    ///@notice Total number of users that received a PowerSeller badge
    uint256 private _totalPowersellers;
    ///@notice Mapping from user address to tokenId
    mapping (address => uint256) public tokenIds;

    /************************************** Modifiers *****************************************************/

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
    constructor() ERC721("Faillapop Powerseller NFT", "FPSNFT") {
        _grantRole(CONTROL_ROLE, msg.sender);
    }
    
    /**
        @notice Sets the shop address as the new Control role
        @param shopAddress The address of the shop contract
    */
    function setShop(address shopAddress) external onlyRole(CONTROL_ROLE) shopNotSet {
        _shopSet = true;
        _grantRole(CONTROL_ROLE, shopAddress);
    }

    /**
        @notice Mints a PowerSeller badge for the user
        @param to The address of the user that will receive the badge
    */
    function safeMint(address to) external onlyRole(CONTROL_ROLE) {
        require(tokenIds[to] == 0, "This user is already a Powerseller");
        nextTokenId++;
        _totalPowersellers++;
        tokenIds[to] = nextTokenId;
        _safeMint(to, nextTokenId);

        emit PowersellerNFT_Minted(msg.sender, nextTokenId);
    }

    /**
        @notice Removes the PowerSeller badge from a user
        @param user The address of the user that will lose the badge
    */
    function removePowersellerNFT(address user) external onlyRole(CONTROL_ROLE) {
        require(tokenIds[user] != 0, "This user is not a Powerseller");
        uint256 tokenId = tokenIds[user];
        tokenIds[user] = 0;
        _totalPowersellers--;
        _burn(tokenId);

        emit PowersellerNFT_Removed(msg.sender, tokenId);
    }

    ///@notice Returns the total number of users that received a PowerSeller badge
    function totalPowersellers() external view returns (uint256) {
        return _totalPowersellers;
    }

    /**
        @notice Checks if the address holds a Trusted badge
        @param user The address of the user to check
    */
    function checkPrivilege(address user) external view returns (bool) {
        return tokenIds[user] != 0;
    }

    /************************************** Public  ****************************************************************/
    /**
     * @notice Powerseller NFTs cannot be transferred, so this function is overriden to revert
     */
    function approve(address /*to*/, uint256 /*tokenId*/) public virtual override{
        revert("PowersellerNFT cannot be approved");
    }
    /**
     * @notice Powerseller NFTs cannot be transferred, so this function is overriden to revert
     */
    function setApprovalForAll(address /*operator*/, bool /*approved*/) public virtual override{
        revert("PowersellerNFT cannot be approved");
    }
    /**
     * @notice Powerseller NFTs cannot be transferred, so this function is overriden to revert
     */
    function transferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) public virtual override{
        revert("PowersellerNFT cannot be transferred");
    }
    /**
     * @notice Powerseller NFTs cannot be transferred, so this function is overriden to revert
     */
    function safeTransferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/, bytes memory /*data*/) public virtual override{
        revert("PowersellerNFT cannot be transferred");
    }

    /**
        @notice Returns the supported interfaces collection
        @param interfaceId The interface identifier
    */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }

}