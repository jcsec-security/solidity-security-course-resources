// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_Shop} from "../../src/Faillapop_shop.sol";
import {FP_Vault} from "../../src/Faillapop_vault.sol";

contract Faillapop_vault_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;

    address public constant NFT_ADDRESS = address(1);
    address public constant FPT_ADDRESS = address(2);
    address public constant USER1 = address(3);

    /************************************* Modifiers *************************************/

    modifier doStake(address user, uint256 amount){
        vm.prank(user);
        vault.doStake{value: amount}();
        _;
    }

    modifier doLock(address user, uint256 amount){
        vm.prank(address(shop));
        vault.doLock(user, amount);
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(USER1, 10 ether);

        dao = new FP_DAO("password", NFT_ADDRESS, FPT_ADDRESS);
        vault = new FP_Vault(FPT_ADDRESS, address(dao));
        shop = new FP_Shop(address(dao), address(vault));
        vault.setShop(address(shop));
        dao.setShop(address(shop));
    }

    /************************************** Tests **************************************/  

    function test_setShop() public {
        assertTrue(vault.hasRole(keccak256("CONTROL_ROLE"), address(shop)));
        assertEq(address(vault.shopContract()), address(shop));
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

        vm.prank(address(shop));
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
        vm.prank(address(shop));
        vm.expectRevert("Amount cannot be zero");
        vault.doLock(USER1, 0 ether);
    }

    function test_doLock_RevertIf_AmountIsGreaterThanStake() public doStake(USER1, 2 ether) { 
        vm.prank(address(shop));
        vm.expectRevert();
        vault.doLock(USER1, 3 ether);
    }

    function test_doUnlock() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 userLockedBefore = vault.userLockedBalance(USER1);
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(address(shop));
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
        vm.prank(address(shop));
        vm.expectRevert("Amount cannot be zero");
        vault.doUnlock(USER1, 0 ether);
    }

    function test_doUnlock_RevertIf_AmountIsGreaterThanLocked() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        vm.prank(address(shop));
        vm.expectRevert("Not enough locked funds");
        vault.doUnlock(USER1, 3 ether);
    }

    function test_doSlash() public doStake(USER1, 2 ether) doLock(USER1, 1 ether) {
        uint256 totalSlashedBefore = vault.totalSlashed();
        uint256 userStakeBefore = vault.userBalance(USER1);
        uint256 vaultBalanceBefore = vault.vaultBalance();

        vm.prank(address(shop));
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
}