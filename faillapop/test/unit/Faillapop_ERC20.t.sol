// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_Token} from "../../src/Faillapop_ERC20.sol";

contract Faillapop_ERC20_Test is Test {

    FP_Token public fpToken;
    address constant ADMIN = address(0x1);
    address constant USER = address(0x2);

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(ADMIN, 10);
        vm.deal(USER, 10);
        vm.prank(ADMIN);
        fpToken = new FP_Token();
    }

    /************************************** Tests **************************************/

    function test_setUp() public {
        assertTrue(fpToken.hasRole(0x00, address(ADMIN)), "Owner should have DEFAULT_ADMIN_ROLE");
        assertTrue(fpToken.hasRole(bytes32(fpToken.PAUSER_ROLE()), address(ADMIN)), "Owner should have PAUSER_ROLE");
        assertTrue(fpToken.hasRole(bytes32(fpToken.MINTER_ROLE()), address(ADMIN)), "Owner should have MINTER_ROLE");
        assertEq(fpToken.balanceOf(address(ADMIN)), 1000000 * 10 ** fpToken.decimals(), "Incorrect token balance after minting");
    }

    function testTokenNameAndSymbol() public {
        assertEq(fpToken.name(), "FaillaPop Token", "Incorrect token name");
        assertEq(fpToken.symbol(), "FPT", "Incorrect token symbol");
    }

    function test_pause() public {
        vm.prank(ADMIN);
        fpToken.pause();

        assertTrue(fpToken.paused(), "Contract should be paused");
    }

    function test_pause_RevertIf_CallerIsNotPauser() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER), keccak256("PAUSER_ROLE")));
        fpToken.pause();
    }

    function test_unpause() public {
        vm.startPrank(ADMIN);
        fpToken.pause();
        fpToken.unpause();
        vm.stopPrank();
        assertFalse(fpToken.paused(), "Contract should be unpaused");
    }

    function test_unpause_RevertIf_CallerIsNotPauser() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER), keccak256("PAUSER_ROLE")));
        fpToken.unpause();
    }

    function test_mint() public {
        address to = USER;
        uint256 amount = 1000;

        vm.prank(ADMIN);
        fpToken.mint(to, amount);

        assertEq(fpToken.balanceOf(to), amount, "Incorrect token balance after minting");
    }

    function test_mint_RevertIf_CallerIsNotMinter() public {
        address to = USER;
        uint256 amount = 1000;

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER), keccak256("MINTER_ROLE")));
        fpToken.mint(to, amount);

        assertEq(fpToken.balanceOf(to), 0, "Incorrect token balance after minting");
    }

}