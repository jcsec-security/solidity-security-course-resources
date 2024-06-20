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

contract Faillapop_Proxy_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;
    FP_Token public token;
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;
    FP_Proxy public proxy;

    /************************************** Set Up **************************************/

    function setUp() external {        
        DeployFaillapop deploy = new DeployFaillapop();
        (shop, token, coolNFT, powersellerNFT, dao, vault, proxy) = deploy.run();
    }

    /************************************** Tests **************************************/  

    function test_setUp() external {
        assertEq(proxy.DAO_ADDRESS(), address(dao));
        assertEq(proxy.getImplementation(), address(shop));
    }

    function test_upgradeToAndCall() external {
        FP_Shop newShop = new FP_Shop();
        vm.prank(address(dao));
        proxy.upgradeToAndCall(
            address(newShop), 
            ""
        );
        assertEq(proxy.getImplementation(), address(newShop));
    }

    function test_upgradeToAndCall_RevertIf_CallerIsNotTheDao() external {
        FP_Shop newShop = new FP_Shop();
        vm.expectRevert("AccessControlUnauthorizedAccount");
        proxy.upgradeToAndCall(
            address(newShop), 
            ""
        );        
    }
}