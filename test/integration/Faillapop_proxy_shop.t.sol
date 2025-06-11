// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/FP_CoolNFT.sol";
import {FP_DAO} from "../../src/FP_DAO.sol";
import {FP_PowersellerNFT} from "../../src/FP_PowersellerNFT.sol";
import {FP_Shop} from "../../src/FP_Shop.sol";
import {IFP_Shop} from "../../src/interfaces/IFP_Shop.sol";
import {FP_Token} from "../../src/FP_Token.sol";
import {FP_Vault} from "../../src/FP_Vault.sol";
import {FP_Proxy} from "../../src/FP_Proxy.sol";
import {DeployFaillapop} from "../../script/DeployFaillapop.s.sol";

contract Faillapop_proxy_shop_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;
    FP_Token public token;
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;
    FP_Proxy public proxy;

    address public constant SELLER1 = address(3);
    address public constant BUYER1 = address(4);
    address public constant USER1 = address(5);

    /************************************* Modifiers *************************************/

    modifier createLegitSale() {
        // Simulate a user's stake in the Vault
        vm.prank(SELLER1);
        vault.doStake{value: 2 ether}();

        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        

        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertTrue(success, "Sale not created");        
        _;
    }

    modifier cancelLastActiveSale() {
        (bool success, bytes memory data) = _getOfferIndex();
        assertTrue(success, "Offer index not retrieved");
        uint256 saleId = abi.decode(data, (uint256)) - 1;
        
        vm.prank(SELLER1);
        bool success2 = _cancelActiveSale(saleId);
        assertTrue(success2, "Sale not canceled");  
        _;
    }

    modifier setVacationMode() {
        vm.prank(SELLER1);
        bool success = _setVacationMode(true);
        assertTrue(success, "Vacation mode not set correctly");  
        _;
    }

    modifier buyLastItem() {
        (bool success, bytes memory data) = _getOfferIndex();
        assertTrue(success, "Offer index not retrieved");
        uint256 saleId = abi.decode(data, (uint256)) - 1;

        vm.prank(BUYER1);
        bool success2 = _doBuy(saleId, 1 ether);
        assertTrue(success2, "Sale not bought");
        _;
    }

    modifier itemReceived() {
        (bool success, bytes memory data) = _getOfferIndex();
        assertTrue(success, "Offer index not retrieved");
        uint256 saleId = abi.decode(data, (uint256)) - 1;

        vm.prank(BUYER1);
        bool success2 = _itemReceived(saleId);
        assertTrue(success2, "ItemReceived call failed");
        _;
    }

    modifier disputeSale() {
        vm.prank(BUYER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertTrue(success, "Sale not disputed");
        _;
    }

    modifier replyDisputedSale() {
        vm.prank(SELLER1);
        bool success = _disputedSaleReply(0, "Seller's reasoning");
        assertTrue(success, "Disputed sale not replied");
        _;
    }
    
    modifier doStake(address user, uint256 amount) {
        vm.prank(user);
        vault.doStake{value: amount}();
        _;
    }

    /************************************** Set Up **************************************/

    function setUp() external {
        vm.deal(SELLER1, 15 ether);
        vm.deal(BUYER1, 15 ether);
        vm.deal(USER1, 15 ether);

        DeployFaillapop deploy = new DeployFaillapop();
        (shop, token, coolNFT, powersellerNFT, dao, vault, proxy) = deploy.run();
    }

    /************************************** Tests **************************************/  

    function test_doBuy() public createLegitSale() {
        // Buy item
        vm.prank(BUYER1);
        bool success = _doBuy(0, 1 ether); 
        assertTrue(success, "Sale not bought");

        // Check the correct purchase of the item
        (bool success2, bytes memory data) = _querySale(0);
        assertTrue(success2, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));
        
        assertEq(sale.seller, SELLER1, "Wrong seller, sale purchase failed");
        assertEq(sale.buyer, BUYER1, "Wrong buyer, sale purchase failed");
        assertEq(uint(sale.state), uint(IFP_Shop.State.Pending), "Wrong state, sale purchase failed");
        assertEq(sale.buyTimestamp, block.timestamp, "Wrong timestamp, sale purchase failed");
    }

    function test_doBuy_RevertIf_SaleIsUndefined() public {
        // Buy undefined item 
        vm.prank(BUYER1);
        bool success = _doBuy(0, 1 ether); 
        assertFalse(success, "Call should revert");
    }

    function test_doBuy_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Buy pending item
        vm.prank(BUYER1);
        bool success = _doBuy(0, 1 ether); 
        assertFalse(success, "Call should revert");
    }

    function test_doBuy_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Buy sold item
        vm.prank(BUYER1);    
        bool success = _doBuy(0, 1 ether); 
        assertFalse(success, "Call should revert");
    }

    function test_doBuy_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Buy on vacation item
        vm.prank(BUYER1);
        bool success = _doBuy(0, 1 ether); 
        assertFalse(success, "Call should revert");
    }

    function test_disputeSale() public createLegitSale() buyLastItem() {
        // Dispute sale
        vm.prank(BUYER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertTrue(success, "Sale not disputed");

        // Check the correct dispute of the sale
        (bool success2, bytes memory data) = _querySale(0);
        assertTrue(success2, "Sale not queried");
        IFP_Shop.Sale memory disputedSale = abi.decode(data, (IFP_Shop.Sale));

        (bool success3, bytes memory data2) = _queryDispute(0);
        assertTrue(success3, "Dispute not queried");
        IFP_Shop.Dispute memory dispute = abi.decode(data2, (IFP_Shop.Dispute));    

        assertEq(disputedSale.seller, SELLER1, "Wrong seller, sale dispute failed");
        assertEq(disputedSale.buyer, BUYER1, "Wrong buyer, sale dispute failed");
        assertEq(uint(disputedSale.state), uint(IFP_Shop.State.Disputed), "Wrong state, sale dispute failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, sale dispute failed");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning, sale dispute failed");
    }

    function test_disputeSale_RevertIf_CallerIsNotTheBuyer() public createLegitSale() buyLastItem() {
        // Dispute sale
        vm.prank(USER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertFalse(success, "Call should revert");
    } 

    function test_disputeSale_RevertIf_SaleIsUndefined() public { 
        // Dispute sale
        vm.prank(USER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputeSale_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Dispute sale
        vm.prank(USER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputeSale_RevertIf_SaleIsSelling() public createLegitSale() {
        // Dispute sale
        vm.prank(USER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertFalse(success, "Call should revert");
}

    function test_disputeSale_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Dispute sale
        vm.prank(USER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputeSale_RevertIf_SaleIsDisputed() public createLegitSale() buyLastItem() disputeSale() {
        // Dispute sale
        vm.prank(BUYER1);
        bool success = _disputeSale(0, "Buyer's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_itemReceived_FromBuyer() public createLegitSale() buyLastItem() {
        // confirm item received
        vm.prank(BUYER1);
        bool success = _itemReceived(0);
        assertTrue(success, "ItemReceived call failed");

        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);

        // Check the correct confirmation of the item received
        (bool success2, bytes memory data) = _querySale(0);
        assertTrue(success2, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));

        assertEq(sale.seller, address(0), "Wrong seller, item received failed");
        assertEq(sale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(sale.title, "", "Wrong title, item received failed");
        assertEq(sale.description, "", "Wrong description, item received failed");
        assertEq(sale.price, 0, "Wrong price, item received failed");
        assertEq(uint(sale.state), uint(IFP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(sale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
    }

    function test_itemReceived_RevertIf_CallerIsNotTheBuyerOrTheSeller() public createLegitSale() buyLastItem() {
        // confirm item received
        vm.prank(USER1);
        bool success = _itemReceived(0);
        assertFalse(success, "Call should revert");
    }

    function test_itemReceived_FromSeller() public createLegitSale() buyLastItem() {
        // block.timestamp manipulation
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));

        vm.warp(sale.buyTimestamp + 30 days);
        
        // confirm item received
        vm.prank(SELLER1);
        bool success2 = _itemReceived(0);
        assertTrue(success2, "ItemReceived call failed");

        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);

        // Check the correct confirmation of the item received
        (bool success3, bytes memory data2) = _querySale(0);
        assertTrue(success3, "Sale not queried");
        sale = abi.decode(data2, (IFP_Shop.Sale));

        assertEq(sale.seller, address(0), "Wrong seller, item received failed");
        assertEq(sale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(sale.title, "", "Wrong title, item received failed");
        assertEq(sale.description, "", "Wrong description, item received failed");
        assertEq(sale.price, 0, "Wrong price, item received failed");
        assertEq(uint(sale.state), uint(IFP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(sale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
    }  

    function test_itemReceived_FromSeller_RevertIf_InsufficientElapsedTime() public createLegitSale() buyLastItem() {
        // block.timestamp manipulation
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));

        vm.warp(sale.buyTimestamp + 25 days);
        
        // confirm item received
        vm.prank(SELLER1);
        bool success2 = _itemReceived(0);
        assertTrue(success2, "Call should revert"); 
    }

    function test_endDispute_FromBuyer() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));

        // End dispute
        vm.prank(BUYER1);
        bool success2 = _endDispute(0);
        assertTrue(success2, "Dispute not ended");

        // Check the correct end of the dispute        
        (bool success3, bytes memory data2) = _querySale(0);
        assertTrue(success3, "Sale not queried");
        IFP_Shop.Sale memory closedSale = abi.decode(data2, (IFP_Shop.Sale));

        (bool success4, bytes memory data3) = _queryDispute(0);
        assertTrue(success4, "Dispute not queried");
        IFP_Shop.Dispute memory dispute = abi.decode(data3, (IFP_Shop.Dispute));

        assertEq(closedSale.seller, address(0), "Wrong seller, item received failed");
        assertEq(closedSale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(closedSale.title, "", "Wrong title, item received failed");
        assertEq(closedSale.description, "", "Wrong description, item received failed");
        assertEq(closedSale.price, 0, "Wrong price, item received failed");
        assertEq(uint(closedSale.state), uint(IFP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(closedSale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, end dispute failed");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning, end dispute failed");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning, end dispute failed");
    }
    
    function test_endDispute_FromDao() public createLegitSale() buyLastItem() disputeSale() {
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));

        
        // End dispute
        vm.prank(address(dao));
        bool success2 = _endDispute(0);
        assertTrue(success2, "Dispute not ended");

        // Check the correct end of the dispute        
        (bool success3, bytes memory data2) = _querySale(0);
        assertTrue(success3, "Sale not queried");
        IFP_Shop.Sale memory closedSale = abi.decode(data2, (IFP_Shop.Sale));

        (bool success4, bytes memory data3) = _queryDispute(0);
        assertTrue(success4, "Dispute not queried");
        IFP_Shop.Dispute memory dispute = abi.decode(data3, (IFP_Shop.Dispute));

        assertEq(closedSale.seller, address(0), "Wrong seller, item received failed");
        assertEq(closedSale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(closedSale.title, "", "Wrong title, item received failed");
        assertEq(closedSale.description, "", "Wrong description, item received failed");
        assertEq(closedSale.price, 0, "Wrong price, item received failed");
        assertEq(uint(closedSale.state), uint(IFP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(closedSale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, end dispute failed");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning, end dispute failed");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning, end dispute failed");
    }

    function test_endDispute_RevertIf_SaleIsUndefined() public {
        // End dispute
        vm.prank(address(dao));
        bool success = _endDispute(0);
        assertFalse(success, "Call should revert");
    }

    function test_endDispute_RevertIf_SaleIsSelling()  public createLegitSale() {
        // End dispute
        vm.prank(address(dao));
        bool success = _endDispute(0);
        assertFalse(success, "Call should revert");
    }

    function test_endDispute_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // End dispute
        vm.prank(address(dao));
        bool success = _endDispute(0);
        assertFalse(success, "Call should revert");
    }

    function test_endDispute_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // End dispute
        vm.prank(address(dao));
        bool success = _endDispute(0);
        assertFalse(success, "Call should revert");
    }

    function test_endDispute_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() {
        // End dispute
        vm.prank(address(dao));
        bool success = _endDispute(0);
        assertFalse(success, "Call should revert");
    }

    function test_newSale() public doStake(SELLER1, 2 ether) {
        // Get initial locked funds
        uint256 lockedFundsBefore = vault.userLockedBalance(SELLER1);

        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertTrue(success, "Sale not created");   
        
        // Check sale creation
        (bool success2, bytes memory data) = _querySale(0);
        assertTrue(success2, "Sale not queried");
        IFP_Shop.Sale memory newSale = abi.decode(data, (IFP_Shop.Sale));
        
        (bool success3, bytes memory data2) = _getOfferIndex();
        assertTrue(success3, "Offer index not retrieved");
        uint256 offerIndex = abi.decode(data2, (uint256));

        assertEq(offerIndex, 1, "Wrong offerIndex, sale creation failed");
        assertEq(newSale.seller, SELLER1, "Wrong seller, sale creation failed");
        assertEq(newSale.title, title, "Wrong title, sale creation failed");
        assertEq(newSale.description, description, "Wrong description, sale creation failed");
        assertEq(newSale.price, price, "Wrong price, sale creation failed");
        assertEq(uint(newSale.state), uint(IFP_Shop.State.Selling), "Wrong state, sale creation failed");

        // Check seller's funds locked in the Vault
        assertEq(vault.userLockedBalance(SELLER1), lockedFundsBefore + price, "Funds not correctly locked");
    }

    function test_newSale_RevertIf_PriceIsZero() public doStake(SELLER1, 2 ether) {
        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 0;        
        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertFalse(success, "Call should revert");
    }

    function test_newSale_RevertIf_TitleIsEmpty() public doStake(SELLER1, 2 ether) {
        // New sale 
        string memory title = "";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertFalse(success, "Call should revert");
    }

    function test_newSale_RevertIf_DescriptionIsEmpty() public doStake(SELLER1, 2 ether) {
        // New sale 
        string memory title = "Test Item";
        string memory description = "";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertFalse(success, "Call should revert");
    }

    function test_newSale_RevertIf_SellerHasNoStakedFunds() public {
        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertFalse(success, "Call should revert");
    }


    function test_newSale_RevertIf_SellerHasNotEnoughStakedFunds() public doStake(SELLER1, 0.5 ether) {
        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        bool success = _newSale(title, description, price);
        assertTrue(success, "Sale not created");
    }


    function test_modifySale() public createLegitSale() {
        // Get amount of funds locked in the Vault by the seller
        uint256 sellerPreviousLockedFunds = vault.userLockedBalance(SELLER1);   

        // Get previous price
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory previousSale = abi.decode(data, (IFP_Shop.Sale));

        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success2 = _modifySale(0, newTitle, newDescription, newPrice);
        assertTrue(success2, "Sale not modified");

        // Check sale modification
        (bool success3, bytes memory data2) = _querySale(0);
        assertTrue(success3, "Sale not queried");
        IFP_Shop.Sale memory actualSale = abi.decode(data2, (IFP_Shop.Sale));

        assertEq(actualSale.seller, SELLER1, "Wrong seller, sale modification failed");
        assertEq(actualSale.title, newTitle, "Wrong title, sale modification failed");
        assertEq(actualSale.description, newDescription, "Wrong description, sale modification failed");
        assertEq(actualSale.price, newPrice, "Wrong price, sale modification failed");
        assertEq(uint(actualSale.state), uint(IFP_Shop.State.Selling), "Wrong state, sale modification failed");

        // Check seller's funds locked in the Vault
        uint256 priceDifference;
        if(previousSale.price > newPrice) {
            priceDifference = previousSale.price - newPrice;
            assertEq(vault.userLockedBalance(SELLER1), sellerPreviousLockedFunds - priceDifference, "Funds not correctly unlocked");
        }else if(previousSale.price <= newPrice) {
            priceDifference = newPrice - previousSale.price;
            assertEq(vault.userLockedBalance(SELLER1), sellerPreviousLockedFunds + priceDifference, "Funds not correctly locked");
        }
    }

    function test_modifySale_RevertIf_PriceIsZero() public createLegitSale() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 0;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_TitleIsEmpty() public createLegitSale() {
        // Modify sale
        string memory newTitle = "";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_DescriptionIsEmpty() public createLegitSale() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_CallerIsNotTheSeller() public createLegitSale() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(USER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_SaleIsUndefined() public {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_SaleIsDisputed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {        
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertFalse(success, "Call should revert");
    }

    function test_modifySale_RevertIf_IncreasingPriceWithoutAddingEnoughStakedFunds() public createLegitSale() {
        // Get amount of funds locked in the Vault by the seller
        uint256 sellerStakedFunds = vault.userBalance(SELLER1); 

        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = sellerStakedFunds + 5 ether;
        vm.prank(SELLER1);
        bool success = _modifySale(0, newTitle, newDescription, newPrice);
        assertTrue(success, "Sale not modified");
    } 

    function test_cancelActiveSale() public createLegitSale() {
        // Get amount of funds locked in the Vault by the seller
        uint256 sellerLockedFundsBefore = vault.userLockedBalance(SELLER1);   

        // Get sale price
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory activeSale = abi.decode(data, (IFP_Shop.Sale));

        //(a >= b)
        assertGe(sellerLockedFundsBefore, activeSale.price, "Something wrong has happened");

        // Cancel active sale
        vm.prank(SELLER1);
        bool success2 = _cancelActiveSale(0);
        assertTrue(success2, "Sale not canceled");  

        // Check sale cancellation
        (bool success3, bytes memory data2) = _querySale(0);
        assertTrue(success3, "Sale not queried");
        IFP_Shop.Sale memory actualSale = abi.decode(data2, (IFP_Shop.Sale));

        assertEq(actualSale.seller, address(0), "Wrong seller, sale cancellation failed");
        assertEq(actualSale.title, "", "Wrong title, sale cancellation failed");
        assertEq(actualSale.description, "", "Wrong description, sale cancellation failed");
        assertEq(actualSale.price, 0, "Wrong price, sale cancellation failed");

        // Check seller's funds locked in the Vault
        assertEq(vault.userLockedBalance(SELLER1), sellerLockedFundsBefore - activeSale.price, "Funds not correctly unlocked");
    }

    function test_cancelActiveSale_RevertIf_CallerIsNotTheSeller() public createLegitSale() {
        // Cancel sale
        vm.prank(USER1);
        bool success = _cancelActiveSale(0);
        assertFalse(success, "Call should revert"); 
    }

    function test_cancelActiveSale_RevertIf_SaleIsUndefined() public {
        // Cancel sale
        vm.prank(SELLER1);
        bool success = _cancelActiveSale(0);
        assertFalse(success, "Call should revert"); 
    }

    function test_cancelActiveSale_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Cancel sale
        vm.prank(SELLER1);
        bool success = _cancelActiveSale(0);
        assertFalse(success, "Call should revert"); 
    }

    function test_cancelActiveSale_RevertIf_SaleIsDisputed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Cancel sale
        vm.prank(SELLER1);
        bool success = _cancelActiveSale(0);
        assertFalse(success, "Call should revert"); 
    }

    function test_cancelActiveSale_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Cancel sale
        vm.prank(SELLER1);
        bool success = _cancelActiveSale(0);
        assertFalse(success, "Call should revert"); 
    }

    function test_cancelActiveSale_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Cancel sale
        vm.prank(SELLER1);
        bool success = _cancelActiveSale(0);
        assertFalse(success, "Call should revert"); 
    }

    function test_disputedSaleReply() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Check the correct reply to the dispute
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory disputedSale = abi.decode(data, (IFP_Shop.Sale));

        (bool success2, bytes memory data2) = _queryDispute(0);
        assertTrue(success2, "Dispute not queried");
        IFP_Shop.Dispute memory dispute = abi.decode(data2, (IFP_Shop.Dispute));

        assertEq(disputedSale.seller, SELLER1, "Wrong seller, sale dispute failed");
        assertEq(disputedSale.buyer, BUYER1, "Wrong buyer, sale dispute failed");
        assertEq(uint(disputedSale.state), uint(IFP_Shop.State.Disputed), "Wrong state, sale dispute failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, sale dispute failed");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning, sale dispute failed");
        assertEq(dispute.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning, sale dispute failed");
    }

    function test_disputedSaleReply_RevertIf_CallerIsNotTheSeller() public createLegitSale() buyLastItem() disputeSale() {
        // Reply to dispute
        vm.prank(USER1);
        bool success = _disputedSaleReply(0, "Seller's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputedSaleReply_RevertIf_SaleIsUndefined() public {
        // Reply to dispute
        vm.prank(SELLER1);
        bool success = _disputedSaleReply(0, "Seller's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputedSaleReply_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Reply to dispute
        vm.prank(SELLER1);
        bool success = _disputedSaleReply(0, "Seller's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputedSaleReply_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Reply to dispute
        vm.prank(SELLER1);
        bool success = _disputedSaleReply(0, "Seller's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_disputedSaleReply_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Reply to dispute
        vm.prank(SELLER1);
        bool success = _disputedSaleReply(0, "Seller's reasoning");
        assertFalse(success, "Call should revert");
    }

    function test_returnItem() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        uint256 balanceBuyerBefore = address(BUYER1).balance;
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerLockedFundsBefore = vault.userLockedBalance(SELLER1);         
        (bool success, bytes memory data) = _querySale(0);
        assertTrue(success, "Sale not queried");
        IFP_Shop.Sale memory sale = abi.decode(data, (IFP_Shop.Sale));

        vm.prank(address(dao));
        bool success2 = _returnItem(0);
        assertTrue(success2, "Item not returned");

        assertEq(address(BUYER1).balance, balanceBuyerBefore + sale.price, "Wrong buyer balance, item returned failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore, "Wrong seller balance, item returned failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerLockedFundsBefore - sale.price, "Wrong locked funds, item returned failed");

        (bool success3, bytes memory data2) = _querySale(0);
        assertTrue(success3, "Sale not queried");
        IFP_Shop.Sale memory actualSale = abi.decode(data2, (IFP_Shop.Sale));

        (bool success4, bytes memory data3) = _queryDispute(0);
        assertTrue(success4, "Dispute not queried");
        IFP_Shop.Dispute memory actualDispute = abi.decode(data3, (IFP_Shop.Dispute));

        assertEq(actualSale.seller, address(0), "Wrong seller, sale cancellation failed");
        assertEq(actualSale.buyer, address(0), "Wrong buyer, sale cancellation failed");
        assertEq(actualSale.title, "", "Wrong title, sale cancellation failed");
        assertEq(actualSale.description, "", "Wrong description, sale cancellation failed");
        assertEq(actualSale.price, 0, "Wrong price, sale cancellation failed");
        assertEq(uint(actualSale.state), uint(IFP_Shop.State.Undefined), "Wrong state, sale cancellation failed");
        assertEq(actualSale.buyTimestamp, 0, "Wrong timestamp, sale cancellation failed");
        assertEq(actualDispute.disputeId, 0, "Wrong disputeId, sale cancellation failed");
        assertEq(actualDispute.buyerReasoning, "", "Wrong buyerReasoning, sale cancellation failed");
        assertEq(actualDispute.sellerReasoning, "", "Wrong sellerReasoning, sale cancellation failed");
    }

    function test_returnItem_RevertIf_CallerIsNotTheDAO() public createLegitSale() buyLastItem() disputeSale() {
        vm.prank(USER1);
        bool success = _returnItem(0);
        assertFalse(success, "Call should revert");
    }

    function test_returnItem_RevertIf_SaleIsUndefined() public {
        vm.prank(address(dao));
        bool success = _returnItem(0);
        assertFalse(success, "Call should revert");
    }

    function test_returnItem_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        vm.prank(address(dao));
        bool success = _returnItem(0);
        assertFalse(success, "Call should revert");
    }

    function test_returnItem_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() {
        vm.prank(address(dao));
        bool success = _returnItem(0);
        assertFalse(success, "Call should revert");
    }

    function test_returnItem_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        vm.prank(address(dao));
        bool success = _returnItem(0);
        assertFalse(success, "Call should revert");
    }

    function test_claimPowersellerBadge() public {
        //Lets recreate 10 valid sales
        vm.prank(SELLER1);
        vault.doStake{value: 10 ether}();
        for(uint i = 0; i < 10; i++) {
            // New sale 
            string memory title = "Test Item";
            string memory description = "This is a test item";
            uint256 price = 0.5 ether;  
              
            vm.prank(SELLER1);
            bool success = _newSale(title, description, price);
            assertTrue(success, "Sale not created");   
            
            (bool success2, bytes memory data) = _getOfferIndex();
            assertTrue(success2, "Offer index not retrieved");
            uint256 saleId = abi.decode(data, (uint256)) - 1;

            vm.startPrank(BUYER1);
            bool success3 = _doBuy(saleId, 0.5 ether);
            assertTrue(success3, "Sale not bought");
            bool success4 = _itemReceived(saleId);
            assertTrue(success4, "ItemReceived call failed");
            vm.stopPrank();
        }_queryNumValidSales(SELLER1);
        
        (bool success5, bytes memory data2) = _queryNumValidSales(SELLER1);
        assertTrue(success5, "Valid sales not retrieved");
        uint256 numValidSales = abi.decode(data2, (uint256));

        assertEq(numValidSales, 10, "Seller should have 10 valid sales");
        assertEq(powersellerNFT.totalPowersellers(), 0, "TotalPowerseller should be 0");
        assertEq(powersellerNFT.balanceOf(SELLER1), 0, "Seller should not have the badge yet");
        assertFalse(powersellerNFT.checkPrivilege(SELLER1), "Seller should not have the badge yet");

        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        bool success6 = _claimPowersellerBadge();
        assertTrue(success6, "Powerseller badge not claimed correctly");
        
        assertEq(powersellerNFT.balanceOf(SELLER1), 1, "Powerseller badge not minted correctly");
        assertTrue(powersellerNFT.checkPrivilege(SELLER1), "Powerseller badge not minted correctly");
        assertEq(powersellerNFT.totalPowersellers(), 1, "Powerseller badge not minted correctly");
    }

    function test_claimPowersellerBadge_RevertIf_NotEnoughTimeElapsed() public {
        //Lets recreate 10 valid sales
        vm.prank(SELLER1);
        vault.doStake{value: 10 ether}();
        for(uint i = 0; i < 10; i++) {
            // New sale 
            string memory title = "Test Item";
            string memory description = "This is a test item";
            uint256 price = 0.5 ether;  
              
            vm.prank(SELLER1);
            bool success = _newSale(title, description, price);
            assertTrue(success, "Sale not created");   
            
            (bool success2, bytes memory data) = _getOfferIndex();
            assertTrue(success2, "Offer index not retrieved");
            uint256 saleId = abi.decode(data, (uint256)) - 1;

            vm.startPrank(BUYER1);            
            bool success3 = _doBuy(saleId, 0.5 ether);
            assertTrue(success3, "Sale not bought");
            bool success4 = _itemReceived(saleId);
            assertTrue(success4, "ItemReceived call failed");
            vm.stopPrank();
        }

        (bool success5, bytes memory data2) = _queryNumValidSales(SELLER1);
        assertTrue(success5, "Valid sales not retrieved");
        uint256 numValidSales = abi.decode(data2, (uint256));
        
        assertEq(numValidSales, 10, "Seller should have 10 valid sales");
        assertEq(powersellerNFT.totalPowersellers(), 0, "TotalPowerseller should be 0");
        assertEq(powersellerNFT.balanceOf(SELLER1), 0, "Seller should not have the badge yet");
        assertFalse(powersellerNFT.checkPrivilege(SELLER1), "Seller should not have the badge yet");

        vm.warp(block.timestamp + 4 weeks);
        vm.prank(SELLER1);
        bool success6 = _claimPowersellerBadge();
        assertFalse(success6, "Call should revert");
    }

    function test_claimPowersellerBadge_RevertIf_NotEnoughValidSales() public createLegitSale() buyLastItem() itemReceived() {
        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        bool success = _claimPowersellerBadge();
        assertFalse(success, "Call should revert");
    }

    function test_claimPowersellerBadge_RevertIf_SellerIsPowerseller() public {
        //Lets recreate 10 valid sales
        vm.prank(SELLER1);
        vault.doStake{value: 10 ether}();
        for(uint i = 0; i < 10; i++) {
            // New sale 
            string memory title = "Test Item";
            string memory description = "This is a test item";
            uint256 price = 0.5 ether;  
              
            vm.prank(SELLER1);
            bool success = _newSale(title, description, price);
            assertTrue(success, "Sale not created");   
            
            (bool success2, bytes memory data) = _getOfferIndex();
            assertTrue(success2, "Offer index not retrieved");
            uint256 saleId = abi.decode(data, (uint256)) - 1;

            vm.startPrank(BUYER1);
            bool success3 = _doBuy(saleId, 0.5 ether);
            assertTrue(success3, "Sale not bought");
            bool success4 = _itemReceived(saleId);
            assertTrue(success4, "ItemReceived call failed");
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        bool success5 = _claimPowersellerBadge();
        assertTrue(success5, "Powerseller badge not claimed correctly");

        vm.prank(SELLER1);
        bool success6 = _claimPowersellerBadge();
        assertFalse(success6, "Call should revert");
    }

    function test_removeMaliciousSale() public createLegitSale() {
        // Remove malicious sale
        bool success = _removeMaliciousSale(0); 
        assertTrue(success, "Malicious sale not removed correctly");

        // Check sale cancellation
        (bool success2, bytes memory data) = _querySale(0);
        assertTrue(success2, "Sale not queried");
        IFP_Shop.Sale memory actualSale = abi.decode(data, (IFP_Shop.Sale));

        assertEq(actualSale.seller, address(0), "Wrong seller, malicious sale removal failed");
        assertEq(actualSale.buyer, address(0), "Wrong buyer, malicious sale removal failed");
        assertEq(actualSale.title, "", "Wrong title, malicious sale removal failed");
        assertEq(actualSale.description, "", "Wrong description, malicious sale removal failed");
        assertEq(actualSale.price, 0, "Wrong price, malicious sale removal failed");
        assertEq(uint(actualSale.state), uint(IFP_Shop.State.Undefined), "Wrong state, malicious sale removal failed");
        assertEq(actualSale.buyTimestamp, 0, "Wrong timestamp, malicious sale removal failed");

        // Check seller's funds locked in the Vault
        assertEq(vault.userLockedBalance(SELLER1), 0, "Funds not correctly slashed"); 
    }

    function test_removeMaliciousSale_FromPowerseller() public createLegitSale() {
        //Lets recreate 10 valid sales
        vm.prank(SELLER1);
        vault.doStake{value: 10 ether}();
        for(uint i = 0; i < 10; i++) {
            // New sale 
            string memory title = "Test Item";
            string memory description = "This is a test item";
            uint256 price = 0.5 ether;  
              
            vm.prank(SELLER1);
            bool success = _newSale(title, description, price);
            assertTrue(success, "Sale not created");   
            
            (bool success2, bytes memory data) = _getOfferIndex();
            assertTrue(success2, "Offer index not retrieved");
            uint256 saleId = abi.decode(data, (uint256)) - 1;

            vm.startPrank(BUYER1);
            bool success3 = _doBuy(saleId, 0.5 ether);
            assertTrue(success3, "Sale not bought");
            bool success4 = _itemReceived(saleId);
            assertTrue(success4, "ItemReceived call failed");
            vm.stopPrank();
        }

        //Claim powerseller badge
        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        bool success5 = _claimPowersellerBadge();
        assertTrue(success5, "Powerseller badge not claimed correctly");

        //Check powerseller badge
        assertEq(powersellerNFT.balanceOf(SELLER1), 1, "Seller should not have the badge yet");
        assertTrue(powersellerNFT.checkPrivilege(SELLER1), "Powerseller badge not minted correctly");
        
        //Create malicious sale
        vm.prank(SELLER1);
        bool success6 = _newSale("Sale", "This is a malicious sale", 0.5 ether);
        assertTrue(success6, "Sale not created");   
        
        (bool success7, bytes memory data2) = _getOfferIndex();
            assertTrue(success7, "Offer index not retrieved");
            uint256 maliciousSaleId = abi.decode(data2, (uint256)) - 1;
        
        // Remove malicious sale
        bool success8 = _removeMaliciousSale(0); 
        assertTrue(success8, "Malicious sale not removed correctly");

        // Check sale cancellation
        (bool success9, bytes memory data3) = _querySale(maliciousSaleId);
        assertTrue(success9, "Sale not queried");
        IFP_Shop.Sale memory actualSale = abi.decode(data3, (IFP_Shop.Sale));
        assertEq(actualSale.seller, address(0), "Wrong seller, malicious sale removal failed");
        assertEq(actualSale.buyer, address(0), "Wrong buyer, malicious sale removal failed");
        assertEq(actualSale.title, "", "Wrong title, malicious sale removal failed");
        assertEq(actualSale.description, "", "Wrong description, malicious sale removal failed");
        assertEq(actualSale.price, 0, "Wrong price, malicious sale removal failed");
        assertEq(uint(actualSale.state), uint(IFP_Shop.State.Undefined), "Wrong state, malicious sale removal failed");
        assertEq(actualSale.buyTimestamp, 0, "Wrong timestamp, malicious sale removal failed");

        // Check seller's funds locked in the Vault
        assertEq(vault.userLockedBalance(SELLER1), 0, "Funds not correctly slashed"); 
    
        //Check powerseller badge
        assertEq(powersellerNFT.balanceOf(SELLER1), 0, "Seller should not have the badge yet");
        assertFalse(powersellerNFT.checkPrivilege(SELLER1), "Powerseller badge not minted correctly");
    }

    function test_removeMaliciousSale_RevertIf_CallerIsNotTheAdmin() public createLegitSale() {
        // Remove malicious sale
        vm.prank(USER1);
        bool success = _removeMaliciousSale(0);    
        assertFalse(success, "Call should revert");
    }

    function test_removeMaliciousSale_RevertIf_SaleIsUndefined() public {
        // Remove malicious sale
        bool success = _removeMaliciousSale(0); 
        assertFalse(success, "Call should revert");
    }



    /*************************************** Internal ********************************************* */

    function _doBuy(uint256 itemId, uint256 callValue) internal returns (bool success) {
        (success, ) = address(proxy).call{value: callValue}(
            abi.encodeWithSignature(
                "doBuy(uint256)",
                itemId
            )
        );
    }

    function _disputeSale(uint256 itemId, string memory buyerReasoning) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "disputeSale(uint256,string)",
                itemId,
                buyerReasoning 
            )
        );
    }

    function _itemReceived(uint256 itemId) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "itemReceived(uint256)",
                itemId
            )
        );
    }
    
    function _endDispute(uint256 itemId) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "endDispute(uint256)",
                itemId
            )
        );    
    }

    function _newSale(string memory title, string memory description, uint256 price) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "newSale(string,string,uint256)",
                title, 
                description, 
                price
            )
        );
    }
    
    function _modifySale(uint256 itemId, string memory newTitle, string memory newDescription, uint256 newPrice) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "modifySale(uint256,string,string,uint256)",
                itemId, 
                newTitle, 
                newDescription, 
                newPrice
            )
        );
    } 

    function _cancelActiveSale(uint256 itemId) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "cancelActiveSale(uint256)",
                itemId
            )
        );
    } 

    function _setVacationMode(bool mode) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "setVacationMode(bool)",
                mode
            )
        );        
    }

    function _disputedSaleReply(uint256 itemId, string memory sellerReasoning) internal returns (bool success) {
        (success,) = address(proxy).call(
            abi.encodeWithSignature(
                "disputedSaleReply(uint256,string)",
                itemId,
                sellerReasoning
            )
        );
    }   

    function _returnItem(uint256 itemId) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "returnItem(uint256)",
                itemId
            )
        );
    }
    
    function _claimPowersellerBadge() internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "claimPowersellerBadge()"
            )
        );        
    }

    function _removeMaliciousSale(uint256 itemId) internal returns (bool success) {
        (success, ) = address(proxy).call(
            abi.encodeWithSignature(
                "removeMaliciousSale(uint256)",
                itemId
            )
        );        
    }
    
    function _queryDispute(uint256 disputeId) internal view returns (bool success, bytes memory data) {
        (success, data) = address(proxy).staticcall(
            abi.encodeWithSignature(
                "queryDispute(uint256)",
                disputeId
            )
        );
    }
    
    function _querySale(uint256 saleId) internal view returns (bool success, bytes memory data) {
        (success, data) = address(proxy).staticcall(
            abi.encodeWithSignature(
                "querySale(uint256)",
                saleId
            )
        );
    }
    
    function _queryNumValidSales(address seller) internal view returns (bool success, bytes memory data) {
        (success, data) = address(proxy).staticcall(
            abi.encodeWithSignature(
                "queryNumValidSales(address)",
                seller
            )
        );
    }

    function _getOfferIndex() internal view returns (bool success, bytes memory data) {
        (success, data) = address(proxy).staticcall(
            abi.encodeWithSignature(
                "offerIndex()" 
            )
        );
    }
}