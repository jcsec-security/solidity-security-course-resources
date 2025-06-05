// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/Faillapop_CoolNFT.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_PowersellerNFT} from "../../src/Faillapop_PowersellerNFT.sol";
import {FP_Shop} from "../../src/Faillapop_Shop.sol";
import {FP_Token} from "../../src/Faillapop_ERC20.sol";
import {FP_Vault} from "../../src/Faillapop_Vault.sol";
import {FP_Proxy} from "../../src/Faillapop_Proxy.sol";
import {DeployFaillapop} from "../../script/DeployFaillapop.s.sol";

contract Faillapop_CoolNFT_Test is Test {
    
    FP_CoolNFT public coolNFT;
    FP_DAO public dao;
    FP_Token public token;     
    FP_Vault public vault;   
    FP_Shop public shop;
    FP_PowersellerNFT public powersellerNFT;
    FP_Proxy public proxy;

    address public constant USER1 = address(0x1);
    address public constant USER2 = address(0x2);

    /************************************** Modifiers **************************************/

    modifier mint(uint256 times) {
        for(uint256 i = 0; i < times; i++) {
            vm.prank(address(dao));
            coolNFT.mintCoolNFT(USER1);
        }
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(USER1, 10);

        DeployFaillapop deploy = new DeployFaillapop();
        (shop, token, coolNFT, powersellerNFT, dao, vault, proxy) = deploy.run();
    }

    /************************************** Tests **************************************/

    function test_SetUp() public view {
        assertEq(coolNFT.name(), "Faillapop Cool NFT", "Incorrect token name");
        assertEq(coolNFT.symbol(), "FCNFT", "Incorrect token symbol");
    }    

    function test_setDao() public view {
        assertTrue(coolNFT.hasRole(bytes32(coolNFT.CONTROL_ROLE()), address(dao)));
    }

    function test_setDao_x2() public {
        vm.prank(address(dao));
        vm.expectRevert(bytes("DAO address already set"));
        coolNFT.setDAO(address(dao));
    }

    function test_setShop() public view {
        assertTrue(coolNFT.hasRole(bytes32(coolNFT.SHOP_ROLE()), address(proxy)));
    }

    function test_setShop_x2() public {
        vm.prank(address(dao));
        vm.expectRevert(bytes("Shop address already set"));
        coolNFT.setShop(address(proxy));
    }

    function test_mintCoolNFT() public mint(1) {
        uint256[] memory userTokenIds = coolNFT.getTokenIds(USER1);
        assertEq(coolNFT.balanceOf(USER1), 1, "Incorrect balance");
        assertEq(userTokenIds[userTokenIds.length-1], 1, "Incorrect tokenId");
        assertEq(coolNFT.ownerOf(1), USER1, "Incorrect owner");
    }

    function test_mintCoolNFT_multipleTimes() public mint(15) {
        uint256[] memory userTokenIds = coolNFT.getTokenIds(USER1);
        assertEq(coolNFT.balanceOf(USER1), 15, "Incorrect balance");
        for(uint256 i = 0; i < userTokenIds.length; i++) {
            assertEq(userTokenIds[i], i+1, "Incorrect tokenId");
            assertEq(coolNFT.ownerOf(i+1), USER1, "Incorrect owner");
        }
    }

    function test_mintCoolNFT_RevertIf_CallerIsNotDao() public {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        coolNFT.mintCoolNFT(USER1);
    }
    
    function test_burnAll() public mint(1) {
        vm.prank(address(proxy));
        coolNFT.burnAll(USER1);
        uint256[] memory userTokenIds = coolNFT.getTokenIds(USER1);
        
        assertEq(coolNFT.balanceOf(USER1), 0, "Incorrect balance");
        assertEq(userTokenIds.length, 0, "Incorrect tokenId");
    }

    function test_burnAll_multipleCoolNFTs() public mint(15) {
        vm.prank(address(proxy));
        coolNFT.burnAll(USER1);
        uint256[] memory userTokenIds = coolNFT.getTokenIds(USER1);

        assertEq(coolNFT.balanceOf(USER1), 0, "Incorrect balance");
        assertEq(userTokenIds.length, 0, "Incorrect tokenId");
    }

    function test_burnAll_RevertIf_CallerIsNotShop() public {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("SHOP_ROLE")));
        coolNFT.burnAll(USER1);
    }

    function test_approve() public mint(1) {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be approved"));
        coolNFT.approve(USER2, 1);
    }

    function test_setApprovalForAll() public mint(1) {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be approved"));
        coolNFT.setApprovalForAll(USER2, true);
    }
    
    function test_transferFrom() public mint(1) {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be transferred"));
        coolNFT.transferFrom(USER1, USER2, 1);
    }

    function test_safeTransferFrom() public mint(1) {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be transferred"));
        coolNFT.safeTransferFrom(USER1, USER2, 1);
    }
    
    function test_safeTransferFrom_withData() public mint(1) {
        vm.prank(USER1);
        vm.expectRevert(bytes("CoolNFT cannot be transferred"));
        coolNFT.safeTransferFrom(USER1, USER2, 1, "data");
    }
}