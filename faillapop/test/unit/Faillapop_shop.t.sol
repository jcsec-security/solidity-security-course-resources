// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {FP_CoolNFT} from "../../src/Faillapop_CoolNFT.sol";
import {FP_DAO} from "../../src/Faillapop_DAO.sol";
import {FP_PowersellerNFT} from "../../src/Faillapop_PowersellerNFT.sol";
import {FP_Shop} from "../../src/Faillapop_shop.sol";
import {FP_Token} from "../../src/Faillapop_ERC20.sol";
import {FP_Vault} from "../../src/Faillapop_vault.sol";

/**
 * @title Faillapop Shop Unit Test
 * @dev This test suite focuses on evaluating the functionality of the Faillapop Shop contract
 *      in isolation, without involving the proxy. 
 * @notice In the Faillapop project, the shop contract serves as the logic contract and is used 
 *      through a proxy. However, this specific test suite is designed to isolate
 *      and scrutinize the internal logic of the shop without the involvement of the proxy.
 */

contract Faillapop_shop_Test is Test {

    FP_Shop public shop;
    FP_Vault public vault;
    FP_DAO public dao;
    FP_Token public token;
    FP_CoolNFT public coolNFT;
    FP_PowersellerNFT public powersellerNFT;

    ///@notice The maximum time that a dispute can be kept waiting for a seller's reply
    uint256 public constant MAX_DISPUTE_WAITING_FOR_REPLY = 15 days;

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
        shop.newSale(title, description, price);
        _;
    }

    modifier cancelLastActiveSale() {
        vm.prank(SELLER1);
        uint256 saleId = shop.offerIndex() - 1;
        shop.cancelActiveSale(saleId);
        _;
    }

    modifier setVacationMode() {
        vm.prank(SELLER1);
        shop.setVacationMode(true);
        _;
    }

    modifier buyLastItem() {
        uint256 saleId = shop.offerIndex() - 1;
        vm.prank(BUYER1);
        shop.doBuy{value: 1 ether}(saleId);
        _;
    }

    modifier itemReceived() {
        uint256 saleId = shop.offerIndex() - 1;
        vm.prank(BUYER1);
        shop.itemReceived(saleId);
        _;
    }

    modifier disputeSale() {
        vm.prank(BUYER1);
        shop.disputeSale(0, "Buyer's reasoning");
        _;
    }

    modifier replyDisputedSale() {
        vm.prank(SELLER1);
        shop.disputedSaleReply(0, "Seller's reasoning");
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
        
        shop = new FP_Shop();
        token = new FP_Token();
        coolNFT = new FP_CoolNFT();
        powersellerNFT = new FP_PowersellerNFT();
        dao = new FP_DAO("password", address(coolNFT), address(token));
        vault = new FP_Vault(address(powersellerNFT), address(dao));

        shop.initialize(address(dao), address(vault), address(powersellerNFT), address(coolNFT));

        vault.setShop(address(shop));
        dao.setShop(address(shop));
        powersellerNFT.setShop(address(shop));
        coolNFT.setDAO(address(dao));
    }

    /************************************** Tests **************************************/  

    function test_doBuy() public createLegitSale() {
        // Buy item
        vm.prank(BUYER1);
        shop.doBuy{value: 1 ether}(0);

        // Check the correct purchase of the item
        FP_Shop.Sale memory sale = shop.querySale(0);
        
        assertEq(sale.seller, SELLER1, "Wrong seller, sale purchase failed");
        assertEq(sale.buyer, BUYER1, "Wrong buyer, sale purchase failed");
        assertEq(uint(sale.state), uint(FP_Shop.State.Pending), "Wrong state, sale purchase failed");
        assertEq(sale.buyTimestamp, block.timestamp, "Wrong timestamp, sale purchase failed");
    }

    function test_doBuy_RevertIf_SaleIsUndefined() public {
        // Buy undefined item 
        vm.prank(BUYER1);
        vm.expectRevert(bytes("itemId does not exist"));
        shop.doBuy{value: 1 ether}(0);
    }

    function test_doBuy_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Buy pending item
        vm.prank(BUYER1);
        vm.expectRevert(bytes("Item cannot be bought"));
        shop.doBuy{value: 1 ether}(0);
    }

    function test_doBuy_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Buy sold item
        vm.prank(BUYER1);
        vm.expectRevert(bytes("itemId does not exist"));
        shop.doBuy{value: 1 ether}(0);
    }

    function test_doBuy_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Buy on vacation item
        vm.prank(BUYER1);
        vm.expectRevert(bytes("Item cannot be bought")); 
        shop.doBuy{value: 1 ether}(0);
    }

    function test_disputeSale() public createLegitSale() buyLastItem() {
        // Dispute sale
        vm.prank(BUYER1);
        shop.disputeSale(0, "Buyer's reasoning");

        // Check the correct dispute of the sale
        FP_Shop.Sale memory disputedSale = shop.querySale(0);
        FP_Shop.Dispute memory dispute = shop.queryDispute(0);
        
        assertEq(disputedSale.seller, SELLER1, "Wrong seller, sale dispute failed");
        assertEq(disputedSale.buyer, BUYER1, "Wrong buyer, sale dispute failed");
        assertEq(uint(disputedSale.state), uint(FP_Shop.State.Disputed), "Wrong state, sale dispute failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, sale dispute failed");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning, sale dispute failed");
        assertEq(dispute.disputeTimestamp, block.timestamp, "Wrong timestamp, sale dispute failed");
    }

    function test_disputeSale_RevertIf_CallerIsNotTheBuyer() public createLegitSale() buyLastItem() {
        // Dispute sale
        vm.prank(USER1);
        vm.expectRevert(bytes("Not the buyer"));
        shop.disputeSale(0, "Buyer's reasoning");
    } 

    function test_disputeSale_RevertIf_SaleIsUndefined() public { 
        // Dispute sale
        vm.prank(USER1);
        vm.expectRevert(bytes("Item not pending"));
        shop.disputeSale(0, "Buyer's reasoning");
    }

    function test_disputeSale_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Dispute sale
        vm.prank(USER1);
        vm.expectRevert(bytes("Item not pending"));
        shop.disputeSale(0, "Buyer's reasoning");
    }

    function test_disputeSale_RevertIf_SaleIsSelling() public createLegitSale() {
        // Dispute sale
        vm.prank(USER1);
        vm.expectRevert(bytes("Item not pending"));
        shop.disputeSale(0, "Buyer's reasoning");
    }

    function test_disputeSale_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Dispute sale
        vm.prank(USER1);
        vm.expectRevert(bytes("Item not pending"));
        shop.disputeSale(0, "Buyer's reasoning");
    }

    function test_disputeSale_RevertIf_SaleIsDisputed() public createLegitSale() buyLastItem() disputeSale() {
        // Dispute sale
        vm.prank(BUYER1);
        vm.expectRevert(bytes("Item not pending"));
        shop.disputeSale(0, "Buyer's reasoning");
    }

    function test_itemReceived_FromBuyer() public createLegitSale() buyLastItem() {
        // confirm item received
        vm.prank(BUYER1);
        shop.itemReceived(0);

        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);

        // Check the correct confirmation of the item received
        FP_Shop.Sale memory sale = shop.querySale(0);
        assertEq(sale.seller, address(0), "Wrong seller, item received failed");
        assertEq(sale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(sale.title, "", "Wrong title, item received failed");
        assertEq(sale.description, "", "Wrong description, item received failed");
        assertEq(sale.price, 0, "Wrong price, item received failed");
        assertEq(uint(sale.state), uint(FP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(sale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
    }

    function test_itemReceived_RevertIf_CallerIsNotTheBuyerOrTheSeller() public createLegitSale() buyLastItem() {
        // confirm item received
        vm.prank(USER1);
        vm.expectRevert(bytes("Not the buyer"));
        shop.itemReceived(0);
    }

    function test_itemReceived_FromSeller() public createLegitSale() buyLastItem() {
        // block.timestamp manipulation
        FP_Shop.Sale memory sale = shop.querySale(0);
        vm.warp(sale.buyTimestamp + 30 days);
        
        // confirm item received
        vm.prank(SELLER1);
        shop.itemReceived(0);

        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);

        // Check the correct confirmation of the item received
        sale = shop.querySale(0);
        assertEq(sale.seller, address(0), "Wrong seller, item received failed");
        assertEq(sale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(sale.title, "", "Wrong title, item received failed");
        assertEq(sale.description, "", "Wrong description, item received failed");
        assertEq(sale.price, 0, "Wrong price, item received failed");
        assertEq(uint(sale.state), uint(FP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(sale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
    }  

    function test_itemReceived_FromSeller_RevertIf_InsufficientElapsedTime() public createLegitSale() buyLastItem() {
        // block.timestamp manipulation
        FP_Shop.Sale memory sale = shop.querySale(0);
        vm.warp(sale.buyTimestamp + 25 days);
        
        // confirm item received
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Insufficient elapsed time"));
        shop.itemReceived(0);
    }

    function test_endDispute_Replied_FromBuyer() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);
        FP_Shop.Sale memory sale = shop.querySale(0);

        // End dispute
        vm.prank(BUYER1);
        shop.endDispute(0);

        // Check the correct end of the dispute        
        FP_Shop.Sale memory closedSale = shop.querySale(0);
        FP_Shop.Dispute memory dispute = shop.queryDispute(0);

        assertEq(closedSale.seller, address(0), "Wrong seller, item received failed");
        assertEq(closedSale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(closedSale.title, "", "Wrong title, item received failed");
        assertEq(closedSale.description, "", "Wrong description, item received failed");
        assertEq(closedSale.price, 0, "Wrong price, item received failed");
        assertEq(uint(closedSale.state), uint(FP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(closedSale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, end dispute failed");
        assertEq(dispute.disputeTimestamp, 0, "Wrong timestamp, sale dispute failed");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning, end dispute failed");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning, end dispute failed");
    }
    
    function test_endDispute_FromDao() public createLegitSale() buyLastItem() disputeSale() {
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);
        FP_Shop.Sale memory sale = shop.querySale(0);
        
        // End dispute
        vm.prank(address(dao));
        shop.endDispute(0);

        // Check the correct end of the dispute        
        FP_Shop.Sale memory closedSale = shop.querySale(0);
        FP_Shop.Dispute memory dispute = shop.queryDispute(0);

        assertEq(closedSale.seller, address(0), "Wrong seller, item received failed");
        assertEq(closedSale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(closedSale.title, "", "Wrong title, item received failed");
        assertEq(closedSale.description, "", "Wrong description, item received failed");
        assertEq(closedSale.price, 0, "Wrong price, item received failed");
        assertEq(uint(closedSale.state), uint(FP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(closedSale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore + sale.price, "Wrong balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong locked funds, item received failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, end dispute failed");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning, end dispute failed");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning, end dispute failed");
    }

    function test_endDispute_NotReplied_FromBuyer() public createLegitSale() buyLastItem() disputeSale() {
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);
        uint256 balanceBuyerBefore = address(BUYER1).balance;

        FP_Shop.Sale memory sale = shop.querySale(0);

        // End dispute
        vm.warp(block.timestamp + MAX_DISPUTE_WAITING_FOR_REPLY);
        vm.prank(BUYER1);
        shop.endDispute(0);

        // Check the correct end of the dispute        
        FP_Shop.Sale memory closedSale = shop.querySale(0);
        FP_Shop.Dispute memory dispute = shop.queryDispute(0);

        assertEq(closedSale.seller, address(0), "Wrong seller, item received failed");
        assertEq(closedSale.buyer, address(0), "Wrong buyer, item received failed");
        assertEq(closedSale.title, "", "Wrong title, item received failed");
        assertEq(closedSale.description, "", "Wrong description, item received failed");
        assertEq(closedSale.price, 0, "Wrong price, item received failed");
        assertEq(uint(closedSale.state), uint(FP_Shop.State.Undefined), "Wrong state, item received failed");
        assertEq(closedSale.buyTimestamp, 0, "Wrong timestamp, item received failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore, "Wrong seller balance, item received failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerFundsLockedBefore - sale.price, "Wrong seller locked funds, item received failed");
        assertEq(address(BUYER1).balance, balanceBuyerBefore + sale.price, "Wrong buyer balance, item received failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, end dispute failed");
        assertEq(dispute.disputeTimestamp, 0, "Wrong timestamp, sale dispute failed");
        assertEq(dispute.buyerReasoning, "", "Wrong buyerReasoning, end dispute failed");
        assertEq(dispute.sellerReasoning, "", "Wrong sellerReasoning, end dispute failed");
    }

    function test_endDispute_NotReplied_FromBuyer_RevertIf_InsufficientElapsedTime() public createLegitSale() buyLastItem() disputeSale() {
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerFundsLockedBefore = vault.userLockedBalance(SELLER1);
        uint256 balanceBuyerBefore = address(BUYER1).balance;

        FP_Shop.Sale memory sale = shop.querySale(0);

        // End dispute
        vm.warp(block.timestamp + MAX_DISPUTE_WAITING_FOR_REPLY - 3 days);
        vm.prank(BUYER1);
        vm.expectRevert(bytes("Insufficient elapsed time"));
        shop.endDispute(0);
    }

    function test_endDispute_RevertIf_SaleIsUndefined() public {
        // End dispute
        vm.prank(address(dao));
        vm.expectRevert(bytes("Dispute not found"));
        shop.endDispute(0);
    }

    function test_endDispute_RevertIf_SaleIsSelling()  public createLegitSale() {
        // End dispute
        vm.prank(address(dao));
        vm.expectRevert(bytes("Dispute not found"));
        shop.endDispute(0);
    }

    function test_endDispute_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // End dispute
        vm.prank(address(dao));
        vm.expectRevert(bytes("Dispute not found"));
        shop.endDispute(0);
    }

    function test_endDispute_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // End dispute
        vm.prank(address(dao));
        vm.expectRevert(bytes("Dispute not found"));
        shop.endDispute(0);
    }

    function test_endDispute_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() {
        // End dispute
        vm.prank(address(dao));
        vm.expectRevert(bytes("Dispute not found"));
        shop.endDispute(0);
    }

    function test_newSale() public doStake(SELLER1, 2 ether) {
        // Get initial locked funds
        uint256 lockedFundsBefore = vault.userLockedBalance(SELLER1);

        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        shop.newSale(title, description, price);
        
        // Check sale creation
        FP_Shop.Sale memory newSale = shop.querySale(0);
        assertEq(shop.offerIndex(), 1, "Wrong offerIndex, sale creation failed");
        assertEq(newSale.seller, SELLER1, "Wrong seller, sale creation failed");
        assertEq(newSale.title, title, "Wrong title, sale creation failed");
        assertEq(newSale.description, description, "Wrong description, sale creation failed");
        assertEq(newSale.price, price, "Wrong price, sale creation failed");
        assertEq(uint(newSale.state), uint(FP_Shop.State.Selling), "Wrong state, sale creation failed");

        // Check seller's funds locked in the Vault
        assertEq(vault.userLockedBalance(SELLER1), lockedFundsBefore + price, "Funds not correctly locked");
    }

    function test_newSale_RevertIf_PriceIsZero() public doStake(SELLER1, 2 ether) {
        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 0;        
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Price must be greater than 0"));
        shop.newSale(title, description, price);
    }

    function test_newSale_RevertIf_TitleIsEmpty() public doStake(SELLER1, 2 ether) {
        // New sale 
        string memory title = "";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Title cannot be empty"));
        shop.newSale(title, description, price);
    }

    function test_newSale_RevertIf_DescriptionIsEmpty() public doStake(SELLER1, 2 ether) {
        // New sale 
        string memory title = "Test Item";
        string memory description = "";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Description cannot be empty"));
        shop.newSale(title, description, price);
    }

    function test_newSale_RevertIf_SellerHasNoStakedFunds() public {
        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        vm.expectRevert();
        shop.newSale(title, description, price);
    }


    function test_newSale_RevertIf_SellerHasNotEnoughStakedFunds() public doStake(SELLER1, 0.5 ether) {
        // New sale 
        string memory title = "Test Item";
        string memory description = "This is a test item";
        uint256 price = 1 ether;        
        vm.prank(SELLER1);
        shop.newSale(title, description, price);
    }


    function test_modifySale() public createLegitSale() {
        // Get amount of funds locked in the Vault by the seller
        uint256 sellerPreviousLockedFunds = vault.userLockedBalance(SELLER1);   

        // Get previous price
        FP_Shop.Sale memory previousSale = shop.querySale(0);

        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        shop.modifySale(0, newTitle, newDescription, newPrice);

        // Check sale modification
        FP_Shop.Sale memory actualSale = shop.querySale(0);
        assertEq(actualSale.seller, SELLER1, "Wrong seller, sale modification failed");
        assertEq(actualSale.title, newTitle, "Wrong title, sale modification failed");
        assertEq(actualSale.description, newDescription, "Wrong description, sale modification failed");
        assertEq(actualSale.price, newPrice, "Wrong price, sale modification failed");
        assertEq(uint(actualSale.state), uint(FP_Shop.State.Selling), "Wrong state, sale modification failed");

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
        vm.expectRevert(bytes("Price must be greater than 0"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_TitleIsEmpty() public createLegitSale() {
        // Modify sale
        string memory newTitle = "";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Title cannot be empty"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_DescriptionIsEmpty() public createLegitSale() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Description cannot be empty"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_CallerIsNotTheSeller() public createLegitSale() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(USER1);
        vm.expectRevert(bytes("Only the seller can modify the sale"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_SaleIsUndefined() public {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be modified"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be modified"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_SaleIsDisputed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {        
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be modified"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be modified")); 
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = 1.5 ether;
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be modified"));
        shop.modifySale(0, newTitle, newDescription, newPrice);
    }

    function test_modifySale_RevertIf_IncreasingPriceWithoutAddingEnoughStakedFunds() public createLegitSale() {
        // Get amount of funds locked in the Vault by the seller
        uint256 sellerStakedFunds = vault.userBalance(SELLER1); 

        // Modify sale
        string memory newTitle = "New Test Item";
        string memory newDescription = "This is a new test item";
        uint256 newPrice = sellerStakedFunds + 5 ether;
        vm.prank(SELLER1);
        shop.modifySale(0, newTitle, newDescription, newPrice);
    } 

    function test_cancelActiveSale() public createLegitSale() {
        // Get amount of funds locked in the Vault by the seller
        uint256 sellerLockedFundsBefore = vault.userLockedBalance(SELLER1);   

        // Get sale price
        FP_Shop.Sale memory activeSale = shop.querySale(0);

        //(a >= b)
        assertGe(sellerLockedFundsBefore, activeSale.price, "Something wrong has happened");

        // Cancel active sale
        vm.prank(SELLER1);
        shop.cancelActiveSale(0);

        // Check sale cancellation
        FP_Shop.Sale memory actualSale = shop.querySale(0);
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
        vm.expectRevert(bytes("Only the seller can cancel the sale"));
        shop.cancelActiveSale(0);
    }

    function test_cancelActiveSale_RevertIf_SaleIsUndefined() public {
        // Cancel sale
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be cancelled"));
        shop.cancelActiveSale(0);
    }

    function test_cancelActiveSale_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Cancel sale
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be cancelled"));
        shop.cancelActiveSale(0);
    }

    function test_cancelActiveSale_RevertIf_SaleIsDisputed() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Cancel sale
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be cancelled"));
        shop.cancelActiveSale(0);
    }

    function test_cancelActiveSale_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Cancel sale
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be cancelled"));
        shop.cancelActiveSale(0);
    }

    function test_cancelActiveSale_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Cancel sale
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Sale can't be cancelled")); 
        shop.cancelActiveSale(0);
    }

    function test_setVacationMode() public createLegitSale() {
        // Check sale state (Selling)
        (,,,,,FP_Shop.State state,) = shop.offeredItems(0);
        assertEq(uint(state), uint(FP_Shop.State.Selling), "Initial sale state not correct");
        
        // Set vacation mode
        vm.prank(SELLER1);
        shop.setVacationMode(true);
        
        // Check new sale state (Vacation)
        (,,,,,FP_Shop.State newState,) = shop.offeredItems(0);
        assertEq(uint(newState), uint(FP_Shop.State.Vacation), "Vacation mode not set correctly");

        //Switch vacationMode off
        vm.prank(SELLER1);
        shop.setVacationMode(false);

        // Check new sale state (Selling)
        (,,,,,FP_Shop.State finalState,) = shop.offeredItems(0);
        assertEq(uint(finalState), uint(FP_Shop.State.Selling), "Vacation mode unset uncorrectly");
    }  
    
    function test_disputedSaleReply() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        // Check the correct reply to the dispute
        FP_Shop.Sale memory disputedSale = shop.querySale(0);
        FP_Shop.Dispute memory dispute = shop.queryDispute(0);

        assertEq(disputedSale.seller, SELLER1, "Wrong seller, sale dispute failed");
        assertEq(disputedSale.buyer, BUYER1, "Wrong buyer, sale dispute failed");
        assertEq(uint(disputedSale.state), uint(FP_Shop.State.Disputed), "Wrong state, sale dispute failed");
        assertEq(dispute.disputeId, 0, "Wrong disputeId, sale dispute failed");
        assertEq(dispute.buyerReasoning, "Buyer's reasoning", "Wrong buyerReasoning, sale dispute failed");
        assertEq(dispute.sellerReasoning, "Seller's reasoning", "Wrong sellerReasoning, sale dispute failed");
    }

    function test_disputedSaleReply_RevertIf_SellerReasoningIsEmpty() public createLegitSale() buyLastItem() disputeSale() {
        // Reply to dispute
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Seller's reasoning cannot be empty"));
        shop.disputedSaleReply(0, "");
    }

    function test_disputedSaleReply_RevertIf_CallerIsNotTheSeller() public createLegitSale() buyLastItem() disputeSale() {
        // Reply to dispute
        vm.prank(USER1);
        vm.expectRevert(bytes("Not the seller"));
        shop.disputedSaleReply(0, "Seller's reasoning");
    }

    function test_disputedSaleReply_RevertIf_SaleIsUndefined() public {
        // Reply to dispute
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Item not disputed"));
        shop.disputedSaleReply(0, "Seller's reasoning");
    }

    function test_disputedSaleReply_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        // Reply to dispute
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Item not disputed"));
        shop.disputedSaleReply(0, "Seller's reasoning");
    }

    function test_disputedSaleReply_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() { 
        // Reply to dispute
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Item not disputed"));
        shop.disputedSaleReply(0, "Seller's reasoning");
    }

    function test_disputedSaleReply_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        // Reply to dispute
        vm.prank(SELLER1);
        vm.expectRevert(bytes("Item not disputed")); 
        shop.disputedSaleReply(0, "Seller's reasoning");
    }

    function test_returnItem() public createLegitSale() buyLastItem() disputeSale() replyDisputedSale() {
        uint256 balanceBuyerBefore = address(BUYER1).balance;
        uint256 balanceSellerBefore = address(SELLER1).balance;
        uint256 sellerLockedFundsBefore = vault.userLockedBalance(SELLER1);         
        FP_Shop.Sale memory sale = shop.querySale(0);

        vm.prank(address(dao));
        shop.returnItem(0);

        assertEq(address(BUYER1).balance, balanceBuyerBefore + sale.price, "Wrong buyer balance, item returned failed");
        assertEq(address(SELLER1).balance, balanceSellerBefore, "Wrong seller balance, item returned failed");
        assertEq(vault.userLockedBalance(SELLER1), sellerLockedFundsBefore - sale.price, "Wrong locked funds, item returned failed");

        FP_Shop.Sale memory actualSale = shop.querySale(0);
        FP_Shop.Dispute memory actualDispute = shop.queryDispute(0);
        assertEq(actualSale.seller, address(0), "Wrong seller, sale cancellation failed");
        assertEq(actualSale.buyer, address(0), "Wrong buyer, sale cancellation failed");
        assertEq(actualSale.title, "", "Wrong title, sale cancellation failed");
        assertEq(actualSale.description, "", "Wrong description, sale cancellation failed");
        assertEq(actualSale.price, 0, "Wrong price, sale cancellation failed");
        assertEq(uint(actualSale.state), uint(FP_Shop.State.Undefined), "Wrong state, sale cancellation failed");
        assertEq(actualSale.buyTimestamp, 0, "Wrong timestamp, sale cancellation failed");
        assertEq(actualDispute.disputeId, 0, "Wrong disputeId, sale cancellation failed");
        assertEq(actualDispute.buyerReasoning, "", "Wrong buyerReasoning, sale cancellation failed");
        assertEq(actualDispute.sellerReasoning, "", "Wrong sellerReasoning, sale cancellation failed");
    }

    function test_returnItem_RevertIf_CallerIsNotTheDAO() public createLegitSale() buyLastItem() disputeSale() {
        vm.prank(USER1);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("DAO_ROLE")));
        shop.returnItem(0);
    }

    function test_returnItem_RevertIf_SaleIsUndefined() public {
        vm.prank(address(dao));
        vm.expectRevert(bytes("Item not disputed"));
        shop.returnItem(0);
    }

    function test_returnItem_RevertIf_SaleIsPending() public createLegitSale() buyLastItem() {
        vm.prank(address(dao));
        vm.expectRevert(bytes("Item not disputed"));
        shop.returnItem(0);
    }

    function test_returnItem_RevertIf_SaleIsSold() public createLegitSale() buyLastItem() itemReceived() {
        vm.prank(address(dao));
        vm.expectRevert(bytes("Item not disputed"));
        shop.returnItem(0);
    }

    function test_returnItem_RevertIf_SaleIsInVacation() public createLegitSale() setVacationMode() {
        vm.prank(address(dao));
        vm.expectRevert(bytes("Item not disputed")); 
        shop.returnItem(0);
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
            shop.newSale(title, description, price);
            
            uint256 saleId = shop.offerIndex() - 1;
            vm.startPrank(BUYER1);
            shop.doBuy{value: 0.5 ether}(saleId);
            shop.itemReceived(saleId);
            vm.stopPrank();
        }
        
        assertEq(shop.queryNumValidSales(SELLER1), 10, "Seller should have 10 valid sales");
        assertEq(powersellerNFT.totalPowersellers(), 0, "TotalPowerseller should be 0");
        assertEq(powersellerNFT.balanceOf(SELLER1), 0, "Seller should not have the badge yet");
        assertFalse(powersellerNFT.checkPrivilege(SELLER1), "Seller should not have the badge yet");

        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        shop.claimPowersellerBadge();
        
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
            shop.newSale(title, description, price);
            
            uint256 saleId = shop.offerIndex() - 1;
            vm.startPrank(BUYER1);
            shop.doBuy{value: 0.5 ether}(saleId);
            shop.itemReceived(saleId);
            vm.stopPrank();
        }
        
        assertEq(shop.queryNumValidSales(SELLER1), 10, "Seller should have 10 valid sales");
        assertEq(powersellerNFT.totalPowersellers(), 0, "TotalPowerseller should be 0");
        assertEq(powersellerNFT.balanceOf(SELLER1), 0, "Seller should not have the badge yet");
        assertFalse(powersellerNFT.checkPrivilege(SELLER1), "Seller should not have the badge yet");

        vm.warp(block.timestamp + 4 weeks);
        vm.expectRevert(bytes("Not enough time has elapsed"));
        vm.prank(SELLER1);
        shop.claimPowersellerBadge();
    }

    function test_claimPowersellerBadge_RevertIf_NotEnoughValidSales() public createLegitSale() buyLastItem() itemReceived() {
        vm.warp(block.timestamp + 6 weeks);
        vm.expectRevert(bytes("Not enough valid sales"));
        vm.prank(SELLER1);
        shop.claimPowersellerBadge();
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
            shop.newSale(title, description, price);
            
            uint256 saleId = shop.offerIndex() - 1;
            vm.startPrank(BUYER1);
            shop.doBuy{value: 0.5 ether}(saleId);
            shop.itemReceived(saleId);
            vm.stopPrank();
        }

        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        shop.claimPowersellerBadge();

        vm.expectRevert("This user is already a Powerseller");
        vm.prank(SELLER1);
        shop.claimPowersellerBadge();
    }

    function test_removeMaliciousSale() public createLegitSale() {
        // Remove malicious sale
        shop.removeMaliciousSale(0);

        // Check sale cancellation
        FP_Shop.Sale memory actualSale = shop.querySale(0);
        assertEq(actualSale.seller, address(0), "Wrong seller, malicious sale removal failed");
        assertEq(actualSale.buyer, address(0), "Wrong buyer, malicious sale removal failed");
        assertEq(actualSale.title, "", "Wrong title, malicious sale removal failed");
        assertEq(actualSale.description, "", "Wrong description, malicious sale removal failed");
        assertEq(actualSale.price, 0, "Wrong price, malicious sale removal failed");
        assertEq(uint(actualSale.state), uint(FP_Shop.State.Undefined), "Wrong state, malicious sale removal failed");
        assertEq(actualSale.buyTimestamp, 0, "Wrong timestamp, malicious sale removal failed");
        assertEq(shop.firstValidSaleTimestamp(SELLER1), 0, "Wrong firstValidSaleTimestamp, malicious sale removal failed");

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
            shop.newSale(title, description, price);
            
            uint256 saleId = shop.offerIndex() - 1;
            vm.startPrank(BUYER1);
            shop.doBuy{value: 0.5 ether}(saleId);
            shop.itemReceived(saleId);
            vm.stopPrank();
        }

        //Claim powerseller badge
        vm.warp(block.timestamp + 6 weeks);
        vm.prank(SELLER1);
        shop.claimPowersellerBadge();

        //Check powerseller badge
        assertEq(powersellerNFT.balanceOf(SELLER1), 1, "Seller should not have the badge yet");
        assertTrue(powersellerNFT.checkPrivilege(SELLER1), "Powerseller badge not minted correctly");
        
        //Create malicious sale
        vm.prank(SELLER1);
        shop.newSale("Sale", "This is a malicious sale", 0.5 ether);
        
        uint256 maliciousSaleId = shop.offerIndex() - 1; 
        
        // Remove malicious sale
        shop.removeMaliciousSale(maliciousSaleId);

        // Check sale cancellation
        FP_Shop.Sale memory actualSale = shop.querySale(maliciousSaleId);
        assertEq(actualSale.seller, address(0), "Wrong seller, malicious sale removal failed");
        assertEq(actualSale.buyer, address(0), "Wrong buyer, malicious sale removal failed");
        assertEq(actualSale.title, "", "Wrong title, malicious sale removal failed");
        assertEq(actualSale.description, "", "Wrong description, malicious sale removal failed");
        assertEq(actualSale.price, 0, "Wrong price, malicious sale removal failed");
        assertEq(uint(actualSale.state), uint(FP_Shop.State.Undefined), "Wrong state, malicious sale removal failed");
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
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(USER1), keccak256("ADMIN_ROLE")));
        shop.removeMaliciousSale(0);
    }

    function test_removeMaliciousSale_RevertIf_SaleIsUndefined() public {
        // Remove malicious sale
        vm.expectRevert(bytes("itemId does not exist"));
        shop.removeMaliciousSale(0);
    }

}