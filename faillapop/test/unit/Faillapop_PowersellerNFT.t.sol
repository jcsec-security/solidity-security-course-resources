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

contract Faillapop_Powerseller_Test is Test {
    
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;
    FP_DAO public dao;     
    FP_Vault public vault;   
    FP_Shop public shop;
    FP_Token public token;
    FP_Proxy public proxy;

    address public constant USER1 = address(0x1);
    address public constant USER2 = address(0x2);

    /************************************** Modifiers **************************************/

    modifier mint() {
        vm.prank(address(proxy));
        powersellerNFT.safeMint(USER1);
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(USER1, 10);

        DeployFaillapop deploy = new DeployFaillapop();
        (shop, token, coolNFT, powersellerNFT, dao, vault, proxy) = deploy.run();
    }

    /************************************** Tests **************************************/

    function test_SetUp() public {
        assertEq(powersellerNFT.name(), "Faillapop Powerseller NFT", "Incorrect token name");
        assertEq(powersellerNFT.symbol(), "FPSNFT", "Incorrect token symbol");
    }    

    function test_setShop() public {
        assertTrue(powersellerNFT.hasRole(bytes32(powersellerNFT.CONTROL_ROLE()), address(proxy)));
    }

    function test_setShop_x2() public {
        vm.prank(address(proxy));
        vm.expectRevert(bytes("Shop address already set"));
        powersellerNFT.setShop(address(proxy));        
    }

    function test_safeMint() public mint() {
        assertEq(powersellerNFT.balanceOf(USER1), 1, "Incorrect balance");
        assertEq(powersellerNFT.ownerOf(1), USER1, "Incorrect owner");
        assertEq(powersellerNFT.tokenIds(USER1), 1, "Incorrect tokenId");
        assertEq(powersellerNFT.totalPowersellers(), 1, "Incorrect totalPowersellers");
        assertTrue(powersellerNFT.checkPrivilege(USER1));
    }

    function test_safeMint_RevertIf_CallerIsNotShop() public {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("CONTROL_ROLE")));
        powersellerNFT.safeMint(USER1);
    }

    function test_safeMint_RevertIf_UserIsAlreadyPowerseller() public mint() {
        vm.prank(address(proxy));
        vm.expectRevert(bytes("This user is already a Powerseller"));
        powersellerNFT.safeMint(USER1);
    }
    
    function test_removePowersellerNFT() public mint() {
        uint256 previousTotalPowersellers = powersellerNFT.totalPowersellers();
        vm.prank(address(proxy));
        powersellerNFT.removePowersellerNFT(USER1);
        
        assertEq(powersellerNFT.balanceOf(USER1), 0, "Incorrect balance");
        assertEq(powersellerNFT.tokenIds(USER1), 0, "Incorrect tokenId");
        assertEq(powersellerNFT.totalPowersellers(), previousTotalPowersellers - 1, "Incorrect totalPowersellers");
        assertFalse(powersellerNFT.checkPrivilege(USER1));
    }

    function test_removePowersellerNFT_RevertIf_UserIsNotPowerseller() public {
        vm.prank(address(proxy));
        vm.expectRevert(bytes("This user is not a Powerseller"));
        powersellerNFT.removePowersellerNFT(USER1);
    }

    function test_approve() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("PowersellerNFT cannot be approved"));
        powersellerNFT.approve(USER2, 1);
    }

    function test_setApprovalForAll() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("PowersellerNFT cannot be approved"));
        powersellerNFT.setApprovalForAll(USER2, true);
    }
    
    function test_transferFrom() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("PowersellerNFT cannot be transferred"));
        powersellerNFT.transferFrom(USER1, USER2, 1);
    }

    function test_safeTransferFrom() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("PowersellerNFT cannot be transferred"));
        powersellerNFT.safeTransferFrom(USER1, USER2, 1);
    }
    
    function test_safeTransferFrom_withData() public mint() {
        vm.prank(USER1);
        vm.expectRevert(bytes("PowersellerNFT cannot be transferred"));
        powersellerNFT.safeTransferFrom(USER1, USER2, 1, "data");
    }
}