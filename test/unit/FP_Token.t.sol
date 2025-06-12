// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_Token} from "../../src/FP_Token.sol";

contract FP_Token_Test is Test {
    address public constant ADMIN = address(bytes20("ADMIN"));
    address public constant USER = address(bytes20("USER"));
    
    FP_Token public token;

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(ADMIN, 10);
        vm.deal(USER, 10);
        vm.prank(ADMIN);
        token = new FP_Token();
    }

    /************************************** Tests **************************************/

    function test_setUp() public {
        assertTrue(token.hasRole(0x00, address(ADMIN)), "Owner should have DEFAULT_ADMIN_ROLE");
        assertTrue(token.hasRole(bytes32(token.PAUSER_ROLE()), address(ADMIN)), "Owner should have PAUSER_ROLE");
        assertTrue(token.hasRole(bytes32(token.MINTER_ROLE()), address(ADMIN)), "Owner should have MINTER_ROLE");
        assertEq(token.balanceOf(address(ADMIN)), 1000000 * 10 ** token.decimals(), "Incorrect token balance after minting");
    }

    function testTokenNameAndSymbol() public {
        assertEq(token.name(), "FaillaPop Token", "Incorrect token name");
        assertEq(token.symbol(), "FPT", "Incorrect token symbol");
    }

    function test_pause() public {
        vm.prank(ADMIN);
        token.pause();

        assertTrue(token.paused(), "Contract should be paused");
    }

    function test_pause_RevertIf_CallerIsNotPauser() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER), keccak256("PAUSER_ROLE")));
        token.pause();
    }

    function test_unpause() public {
        vm.startPrank(ADMIN);
        token.pause();
        token.unpause();
        vm.stopPrank();
        assertFalse(token.paused(), "Contract should be unpaused");
    }

    function test_unpause_RevertIf_CallerIsNotPauser() public {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER), keccak256("PAUSER_ROLE")));
        token.unpause();
    }

    function test_mint() public {
        address to = USER;
        uint256 amount = 1000;

        vm.prank(ADMIN);
        token.mint(to, amount);

        assertEq(token.balanceOf(to), amount, "Incorrect token balance after minting");
    }

    function test_mint_RevertIf_CallerIsNotMinter() public {
        address to = USER;
        uint256 amount = 1000;

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER), keccak256("MINTER_ROLE")));
        token.mint(to, amount);

        assertEq(token.balanceOf(to), 0, "Incorrect token balance after minting");
    }

}