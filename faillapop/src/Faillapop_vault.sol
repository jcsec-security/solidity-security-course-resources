// SPDX-License-Identifier: GPL-3.0 
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IFP_DAO.sol";
import "./interfaces/IFP_Shop.sol";


/** 
    @title FaillaPop vault [v0.2]
    @author Faillapop team :D 
    @notice The contract allows anyone to stake and unstake Ether. When a seller publishes a new item
        in the shop, the funds are locked during the selling process. Then, If the user is considered malicious,
        the funds are slashed. 
    @dev Security review is pending... should we deploy this?
    @custom:ctf This contract is part of JC's mock-audit exercise at https://github.com/jcr-security/solidity-security-teaching-resources
*/
contract FP_Vault is AccessControl {

    /************************************** Constants *******************************************************/

    ///@notice The admin role ID for the AccessControl contract
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    ///@notice The DAO role ID for the AccessControl contract
    bytes32 constant DAO_ROLE = keccak256("DAO_ROLE");
    ///@notice The Shop role ID for the AccessControl contract
    bytes32 constant SHOP_ROLE = keccak256("SHOP_ROLE");


    /************************************** State vars  *******************************************************/
    
    ///@notice The balance of the users in the vault
    mapping (address => uint256) public balance;
    ///@notice The amount of funds locked for selling purposes
    mapping (address => uint256) public lockedFunds;
    ///@notice address of the NFT contract
    address public nftContract;
    ///@notice Shop contract
    IFP_Shop public shopContract;
    ///@notice DAO contract
    IFP_DAO public daoContract;
    ///@notice Maximum claimable amount
    uint256 public max_claimable_amount;
    ///@notice The amount of rewards claimed by each user
    mapping (address => uint256) public rewardsClaimed;
    ///@notice The total amount of funds slashed
    uint256 public totalSlashed;


    /************************************** Events and modifiers *****************************************************/

    ///@notice Emitted when a user stakes funds, contains the user address and the amount staked
    event Stake(address user, uint amount);
    ///@notice Emitted when a user unstakes funds, contains the user address and the amount unstaked
    event Unstake(address user, uint amount);
    ///@notice Emitted when a user funds get locked, contains the user address and the amount locked
    event Locked(address user, uint amount);
    ///@notice Emitted when a user funds get unlocked, contains the user address and the amount unlocked
    event Unlocked(address user, uint amount);
    ///@notice Emitted when a user funds get slashed, contains the user address and the amount slashed
    event Slashed(address user, uint amount);
    ///@notice Emitted when a user claims rewards, contains the user address and the amount claimed
    event RewardsClaimed(address user, uint amount);
    ///@notice Emitted when the contract configuration is changed, contains the address of the Shop, DAO and NFT contracts
    event NewConfig(address shop, address dao, address nft);


    /** 
        @notice Check if the user has enough staked funds to lock or unstake
        @param user The address of the user to check
        @param amount The amount of funds to check
     */
    modifier enoughStaked(address user, uint amount) { 
        // Optimized version of the checks!
        uint userStake = balance[user];
        uint userLocked = lockedFunds[user];
        assembly { 
            if iszero(userStake) {
                mstore(0x00, "No staked funds!")
                revert(0x00, 0x20)
            }

            let res := sub(sub(userStake, userLocked), amount)

            if lt(res, 1) {
                mstore(0x00, "Not enough funds!")
                revert(0x00, 0x20)
            }
        }

        _;
    }


    /************************************** External  ****************************************************************/ 

    /**
        @notice Constructor, initializes the contract
        @param token The address of the powerseller NFT contract
        @param shop The address of the Shop contract
        @param dao The address of the DAO contract
    */
    constructor(address token, address shop, address dao) {
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DAO_ROLE, dao);
        _grantRole(SHOP_ROLE, shop);

        nftContract = token;
        shopContract = IFP_Shop(shop);
        daoContract = IFP_DAO(dao);
    }


    ///@notice Stake attached funds in the vault for later locking, the users must do it on their own
    function doStake() external payable {
        require(msg.value > 0, "Amount cannot be zero");
        balance[msg.sender] += msg.value;
        
        emit Stake(msg.sender, msg.value);
    }
	

    ///@notice Unstake unlocked funds from the vault, the user must do it on their own
    ///@param amount The amount of funds to unstake 
    function doUnstake(uint amount) external enoughStaked(msg.sender, amount) {	
        require(amount > 0, "Amount cannot be zero");

        balance[msg.sender] -= amount;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Unstake failed");

        emit Unstake(msg.sender, amount);
	}


    /**
        @notice Lock funds for selling purposes, the funds are locked until the sale is completed
        @param user The address of the user that is selling
        @param amount The amount of funds to lock
     */
    function doLock(address user, uint amount) external onlyRole(SHOP_ROLE) enoughStaked(user, amount) {
        require(amount > 0, "Amount cannot be zero");
        
        lockedFunds[user] += amount;

        emit Locked(user, amount);
    }


    ///@notice Unlock funds after the sale is completed
    function doUnlock(address user, uint256 amount) external onlyRole(SHOP_ROLE) {
        require(amount > 0, "Amount cannot be zero");
        require(amount <= lockedFunds[user], "Not enough locked funds");

        lockedFunds[user] -= amount;

        emit Unlocked(user, amount);
    }


    ///@notice Slash funds if the user is considered malicious by the DAO
    ///@param badUser The address of the malicious user to be slashed
    function doSlash(address badUser) external onlyRole(DAO_ROLE) {
        uint amount = balance[badUser];

        balance[badUser] = 0;
        lockedFunds[badUser] = 0;

        distributeSlashing(amount);

        emit Slashed(badUser, amount);
    }

    /**
        @notice Modify configuration parameters, only the owner can do it
        @param newDao The address of the new DAO contract
        @param newShop The address of the new Shop contract
        @param newNft The address of the new NFT contract
     */
    function updateConfig(address newDao, address newShop, address newNft) external onlyRole(ADMIN_ROLE) {
        daoContract = IFP_DAO(newDao);
        shopContract = IFP_Shop(newShop);
        nftContract = newNft;

        emit NewConfig(newDao, newShop, newNft);
    }

 
    /**
    @notice Claim rewards generated by slashing malicious users. 
        First checks if the user is elegible through the checkPrivilege function that will revert if not. 
     */
    function claimRewards() external {
        // Checks if the user is elegible
        nftContract.call(
            abi.encodeWithSignature(
                "checkPrivilege(address)",
                msg.sender
            )
        );
        // Checks if the user has already claimed the maximum amount
        require(rewardsClaimed[msg.sender] < max_claimable_amount, "Max claimable amount reached");        

        uint256 amount = max_claimable_amount - rewardsClaimed[msg.sender];

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Rewards payment failed");

        rewardsClaimed[msg.sender] = max_claimable_amount;

        emit RewardsClaimed(msg.sender, amount);
	}


    /************************************** Internal *****************************************************************/

    ///@notice Sets a new maximum claimable amount per user based on the total slashed amount
    function distributeSlashing(uint amount) internal {
        totalSlashed += amount;

        (, bytes memory data) = nftContract.call(abi.encodeWithSignature("totalPowersellers()"));
        uint totalPowersellers = abi.decode(data, (uint256));

        uint newMax = totalSlashed / totalPowersellers;
        max_claimable_amount = newMax;
    } 


    /************************************** Views  *******************************************************/

    ///@notice Get the balance of the vault
	function vaultBalance () public view returns (uint256) {
		return address(this).balance;
	}
	

    ///@notice Get the staked balance of a user
    ///@param user The address of the user to query
	function userBalance (address user) public view returns (uint256) {
		return balance[user];
	}


    ///@notice Get the locked balance of a user
    ///@param user The address of the user to query
	function userLockedBalance (address user) public view returns (uint256) {
		return lockedFunds[user];
	}    
}