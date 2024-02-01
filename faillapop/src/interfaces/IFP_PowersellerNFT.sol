// SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.13;

/** 
    @title Interface of the FaillaPop PowerSeller NFT
    @author Faillapop team :D 
    @notice The contract allows the shop to mint a PowerSeller NFT for users and remove it if they are considered malicious. PowerSeller badge is required to claimRewards in the vault.
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
interface IFP_PowersellerNFT { 
    /**
        @notice Sets the shop address as the new Control role
        @param shopAddress The address of the shop contract
    */
    function setShop(address shopAddress) external;
    
    /**
        @notice Mints a PowerSeller badge for the user
        @param to The address of the user that will receive the badge
    */
    function safeMint(address to) external;

    /**
        @notice Removes the PowerSeller badge from bad a user
        @param maliciousPowerseller The address of the user that will lose the badge
    */
    function removePowersellerNFT(address maliciousPowerseller) external;

    ///@notice Returns the total number of users that received a PowerSeller badge
    function totalPowersellers() external view returns (uint256);

    /**
        @notice Checks if the address holds a Trusted badge
        @param user The address of the user to check
    */
    function checkPrivilege(address user) external view returns (bool);

}
