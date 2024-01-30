// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/Faillapop_CoolNFT.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_PowersellerNFT} from "../../src/Faillapop_PowersellerNFT.sol";
import {FP_Shop} from "../../src/Faillapop_shop.sol";
import {FP_Token} from "../../src/Faillapop_ERC20.sol";
import {FP_Vault} from "../../src/Faillapop_vault.sol";

contract Faillapop_CoolNFT_Test is Test {
    
    FP_CoolNFT public coolNFT;
    FP_DAO public dao;
    FP_Token public token;     
    FP_Vault public vault;   
    FP_Shop public shop;
    FP_PowersellerNFT public powersellerNFT;

    address public constant USER1 = address(0x1);
    address public constant USER2 = address(0x2);

    /************************************** Modifiers **************************************/

    modifier mint {
        vm.prank(address(dao));
        coolNFT.mintCoolNFT(USER1);
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(USER1, 10);

        token = new FP_Token();
        coolNFT = new FP_CoolNFT();
        powersellerNFT = new FP_PowersellerNFT();
        dao = new FP_DAO("password", address(coolNFT), address(token));
        vault = new FP_Vault(address(powersellerNFT), address(dao));
        shop = new FP_Shop(address(dao), address(vault), address(powersellerNFT));

        vault.setShop(address(shop));
        dao.setShop(address(shop));
        powersellerNFT.setShop(address(shop));
        coolNFT.setDAO(address(dao));
    }

    /************************************** Tests **************************************/

    function test_SetUp() public {
        assertEq(coolNFT.name(), "Faillapop Cool NFT", "Incorrect token name");
        assertEq(coolNFT.symbol(), "FCNFT", "Incorrect token symbol");
    }    

    function test_setDao() public {
        assertTrue(coolNFT.hasRole(bytes32(coolNFT.CONTROL_ROLE()), address(dao)));
    }

    function test_setDao_x2() public {
        vm.prank(address(dao));
        vm.expectRevert(bytes("DAO address already set"));
        coolNFT.setDAO(address(dao));
    }

    function test_mintCoolNFT() public mint() {
        assertEq(coolNFT.balanceOf(USER1), 1, "Incorrect balance");
        assertEq(coolNFT.tokenIds(USER1), 1, "Incorrect tokenId");
        assertEq(coolNFT.ownerOf(1), USER1, "Incorrect owner");
    }

    function test_mintCoolNFT_RevertIf_UserAlreadyHasCoolNFT() public mint() {
        vm.prank(address(dao));
        vm.expectRevert(bytes("This user has already a Cool NFT"));
        coolNFT.mintCoolNFT(USER1);
    }

    function test_mintCoolNFT_RevertIf_CallerIsNotDao() public {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        coolNFT.mintCoolNFT(USER1);
    }
    
    function test_burn() public mint() {
        vm.prank(address(dao));
        coolNFT.burn(USER1);
        
        assertEq(coolNFT.balanceOf(USER1), 0, "Incorrect balance");
        assertEq(coolNFT.tokenIds(USER1), 0, "Incorrect tokenId");
    }

    function test_burn_RevertIf_CallerIsNotDao() public {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        coolNFT.burn(USER1);
    }

    function test_burn_RevertIf_UserDoesNotHaveCoolNFT() public {
        vm.prank(address(dao));
        vm.expectRevert(bytes("This user doesn't have a Cool NFT"));
        coolNFT.burn(USER2);
    }

    function test_approve() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be approved"));
        coolNFT.approve(USER2, 1);
    }

    function test_setApprovalForAll() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be approved"));
        coolNFT.setApprovalForAll(USER2, true);
    }
    
    function test_transferFrom() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be transferred"));
        coolNFT.transferFrom(USER1, USER2, 1);
    }

    function test_safeTransferFrom() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be transferred"));
        coolNFT.safeTransferFrom(USER1, USER2, 1);
    }
    
    function test_safeTransferFrom_withData() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be transferred"));
        coolNFT.safeTransferFrom(USER1, USER2, 1, "data");
    }
}
