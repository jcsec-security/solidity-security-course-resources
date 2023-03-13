// SPDX-License-Identifier: GPL-3.0 

pragma solidity ^0.8.13;

interface IFP_NFT {
    ///@notice Returns the total number of users that received a PowerSeller badge
    function totalPowersellers() external view returns (uint256);

    ///@notice Checks if the address holds a Trusted badge
    function checkPrivilege(address user) external view returns (bool);

    ///@notice Mints a cool NFT for the user
    function mintCoolNFT(address user) external;
}