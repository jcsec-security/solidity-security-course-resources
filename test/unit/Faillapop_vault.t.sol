// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/Faillapop_CoolNFT.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_PowersellerNFT} from "../../src/Faillapop_PowersellerNFT.sol";
import {FP_Shop} from "../../src/Faillapop_shop.sol";
import {FP_Token} from "../../src/Faillapop_ERC20.sol";
import {FP_Vault} from "../../src/Faillapop_vault.sol";
import {FP_Proxy} from "../../src/Faillapop_Proxy.sol";
import {DeployFaillapop} from "../../script/DeployFaillapop.s.sol";

contract Faillapop_vault_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;
    FP_Token public token;
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;
    FP_Proxy public proxy;

    address public constant SELLER1 = address(1);
    address public constant SELLER2 = address(2);
    address public constant USER1 = address(3);
    address public constant BUYER1 = address(4);

    /************************************* Modifiers *************************************/

    modifier doStake(address user, uint256 amount) {
        vm.prank(user);
        vault.doStake{value: amount}();
        _;
    }

    modifier doLock(address user, uint256 amount) {
        vm.prank(address(proxy));
        vault.doLock(user, amount);
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(USER1, 15 ether);
        vm.deal(SELLER1, 15 ether);
        vm.deal(SELLER2, 15 ether);
        vm.deal(BUYER1, 15 ether);

        DeployFaillapop deploy = new DeployFaillapop();
        (shop, token, coolNFT, powersellerNFT, dao, vault, proxy) = deploy.run();
    }

    /************************************** Tests **************************************/ 

    function test_setShop() public view {
        assertTrue(vault.hasRole(keccak256("CONTROL_ROLE"), address(proxy)));
    }

    function test_setShop_x2() public {
        vm.prank(address(proxy));
        vm.expectRevert("Shop address already set");
        vault.setShop(address(proxy));
    }

    function test_doStake() public {
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(USER1);
        vault.doStake{value: 2 ether}();

        assertEq(vault.userBalance(USER1), userStakeBefore + 2 ether);
        assertEq(vault.vaultBalance(), vaultBalanceBefore + 2 ether);
        assertEq(vault.userLockedBalance(USER1), 0);
    }

    function test_doStake_RevertIf_ValueIsZero() public {
        vm.prank(USER1);
        vm.expectRevert("Amount cannot be zero");
        vault.doStake{value: 0}();
    }

    function test_doUnstake() public doStake(USER1, 2 ether) {
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 userBalanceBefore = address(USER1).balance;
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(USER1);
        vault.doUnstake(1 ether);

        assertEq(vault.userBalance(USER1), userStakeBefore - 1 ether);
        assertEq(address(USER1).balance, userBalanceBefore + 1 ether);
        assertEq(vault.vaultBalance(), vaultBalanceBefore - 1 ether);
        assertEq(vault.userLockedBalance(USER1), 0);
    }

    function test_doUnstake_RevertIf_AmountIsZero() public doStake(USER1, 2 ether) {
        vm.prank(USER1);
        vm.expectRevert("Amount cannot be zero");
        vault.doUnstake(0);
    }

    function test_doUnstake_RevertIf_AmountIsGreaterThanStake() public doStake(USER1, 2 ether) {
        vm.prank(USER1);
        vm.expectRevert();
        vault.doUnstake(3 ether);
    }

    function test_doLock() public doStake(USER1, 2 ether) {
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 userLockedBefore = vault.userLockedBalance(USER1);
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(address(proxy));
        vault.doLock(USER1, 1 ether);

        assertEq(vault.userBalance(USER1), userStakeBefore);
        assertEq(vault.userLockedBalance(USER1), userLockedBefore + 1 ether);
        assertEq(vault.vaultBalance(), vaultBalanceBefore);
    }

    function test_doLock_RevertIf_CallerIsNotTheShop() public doStake(USER1, 2 ether) {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        vault.doLock(USER1, 1 ether);
    }

    function test_doLock_RevertIf_AmountIsZero() public doStake(USER1, 2 ether) {
        vm.prank(address(proxy));
        vm.expectRevert("Amount cannot be zero");
        vault.doLock(USER1, 0 ether);
    }

    function test_doLock_RevertIf_AmountIsGreaterThanStake() public doStake(USER1, 2 ether) {
        vm.prank(address(proxy));
        vm.expectRevert();
        vault.doLock(USER1, 3 ether);
    }

    function test_doUnlock() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 userLockedBefore = vault.userLockedBalance(USER1);
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(address(proxy));
        vault.doUnlock(USER1, 1 ether);

        assertEq(vault.userBalance(USER1), userStakeBefore);
        assertEq(vault.userLockedBalance(USER1), userLockedBefore - 1 ether);
        assertEq(vault.vaultBalance(), vaultBalanceBefore);
    }

    function test_doUnlock_RevertIf_CallerIsNotTheShop() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        vault.doUnlock(USER1, 1 ether);
    }

    function test_doUnlock_RevertIf_AmountIsZero() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        vm.prank(address(proxy));
        vm.expectRevert("Amount cannot be zero");
        vault.doUnlock(USER1, 0 ether);
    }

    function test_doUnlock_RevertIf_AmountIsGreaterThanLocked() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        vm.prank(address(proxy));
        vm.expectRevert("Not enough locked funds");
        vault.doUnlock(USER1, 3 ether);
    }

    function test_doSlash() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        uint256 totalSlashedBefore = vault.totalSlashed();
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(address(proxy));
        vault.doSlash(USER1);

        assertEq(vault.userBalance(USER1), 0);
        assertEq(vault.userLockedBalance(USER1), 0);
        assertEq(vault.totalSlashed(), totalSlashedBefore + userStakeBefore);
        assertEq(vault.vaultBalance(), vaultBalanceBefore);
    }

    function test_doSlash_RevertIf_CallerIsNotTheShop() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        vault.doSlash(USER1);
    } 

    
    function test_claimRewards() public {
        // Create a powerseller
        //Lets recreate 10 valid sales
        vm.prank(SELLER1);
        vault.doStake{value: 10 ether}();
        for(uint i = 0; i < 10; i++) {
            // New sale 
            string memory title = "Test Item";
            string memory description = "This is a test item";
            uint256 price = 0.5 ether;  
              
            vm.prank(SELLER1);
            (bool success, ) = address(proxy).call(
                abi.encodeWithSignature(
                    "newSale(string,string,uint256)",
                    title, 
                    description, 
                    price
                )
            );
            require(success, "Sale not created");
            
            (bool success2, bytes memory data) = address(proxy).call(
                abi.encodeWithSignature(
                    "offerIndex()" 
                )
            );
            require(success2, "Offer index not retrieved");
            uint256 saleId = abi.decode(data, (uint256)) - 1;

            vm.startPrank(BUYER1);
            (bool success3, ) = address(proxy).call{value: 0.5 ether}(
                abi.encodeWithSignature(
                    "doBuy(uint256)",
                    saleId
                )
            );
            require(success3, "Sale not bought");
            (bool success4, ) = address(proxy).call(
                abi.encodeWithSignature(
                    "itemReceived(uint256)",
                    saleId
                )
            );
            require(success4, "Item not received");
            vm.stopPrank();
        }

        vm.prank(SELLER1);
        vm.warp(block.timestamp + 6 weeks);
        (bool success5, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimPowersellerBadge()"
            )
        );
        require(success5, "Powerseller badge not claimed");

        assertEq(powersellerNFT.balanceOf(SELLER1), 1, "Seller should not have the badge yet");
        assertTrue(powersellerNFT.checkPrivilege(SELLER1), "Powerseller badge not minted correctly");

        //Create malicious sale
        vm.prank(SELLER2);
        vault.doStake{value: 10 ether}();
        vm.prank(SELLER2);
        (bool success6, ) = address(proxy).call(
            abi.encodeWithSignature(
                "newSale(string,string,uint256)",
                "Sale", 
                "This is a malicious sale", 
                0.5 ether
            )
        );
        require(success6, "Malicious sale not created");

        // Remove malicious sale
        (bool success7, bytes memory data2) = address(proxy).call(
                abi.encodeWithSignature(
                    "offerIndex()" 
                )
            );
            require(success7, "Offer index not retrieved");
            uint256 maliciousSaleId = abi.decode(data2, (uint256)) - 1;
        (bool success8, ) = address(proxy).call(
            abi.encodeWithSignature(
                "removeMaliciousSale(uint256)",
                maliciousSaleId
            )
        );
        require(success8, "Malicious sale not removed");

        vm.prank(SELLER1);
        vault.claimRewards();

        assertEq(vault.rewardsClaimed(SELLER1), vault.maxClaimableAmount(), "Seller should have claimed the max amount");   

    }

}