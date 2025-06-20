// SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.13;


/** 
    @title Interface of FaillaPop vault
    @author Faillapop team :D 
    @notice The contract allows anyone to stake and unstake Ether. When a seller publish a new item
    in the shop, the funds are locked during the sale. If the user is considered malicious
    by the DAO, the funds are slashed. 
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/faillapop
*/
interface IFP_Vault {
    
    /************************************** Events *****************************************************/

    ///@notice Emitted when a user stakes funds, contains the user address and the amount staked
    event Stake(address user, uint256 amount);
    ///@notice Emitted when a user unstakes funds, contains the user address and the amount unstaked
    event Unstake(address user, uint256 amount);
    ///@notice Emitted when a user funds get locked, contains the user address and the amount locked
    event Locked(address user, uint256 amount);
    ///@notice Emitted when a user funds get unlocked, contains the user address and the amount unlocked
    event Unlocked(address user, uint256 amount);
    ///@notice Emitted when a user funds get slashed, contains the user address and the amount slashed
    event Slashed(address user, uint256 amount);
    ///@notice Emitted when a user claims rewards, contains the user address and the amount claimed
    event RewardsClaimed(address user, uint256 amount);


    /************************************** Functions *****************************************************/

    /**
        @notice Sets the shop address as the new Control role
        @param shopAddress The address of the shop contract
    */
    function setShop(address shopAddress) external;

    ///@notice Stake attached funds in the vault for later locking, the users must do it on their own
    function doStake() external payable;
	

    ///@notice Unstake unlocked funds from the vault, the user must do it on their own
    ///@param amount The amount of funds to unstake 
    function doUnstake(uint256 amount) external;


    /**
        @notice Lock funds for selling purposes, the funds are locked until the sale is completed
        @param user The address of the user that is selling
        @param amount The amount of funds to lock
     */
    function doLock(address user, uint256 amount) external;


    ///@notice Unlock funds after the sale is completed
    function doUnlock(address user, uint256 amount) external;


    ///@notice Slash funds if the user is considered malicious by the DAO
    ///@param badUser The address of the malicious user to be slashed
    function doSlash(address badUser) external;

 
    /**
    @notice Claim rewards generated by slashing malicious users. 
        First checks if the user is elegible through the checkPrivilege function that will revert if not. 
     */
    function claimRewards() external;
}