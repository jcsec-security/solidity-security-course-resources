pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/102/2-xFn_reentrancy.sol";

contract xFnReenttest is Test  {
    xFnReentrancy public target;
    Attacker public attacker;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);
    address payable mallory = payable(address(0x4));

    function setUp() public {
        //addresses
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");
        vm.label(mallory, "Mallory");

        target = new xFnReentrancy();
        vm.prank(mallory);
        attacker = new Attacker(address(target), mallory);
        vm.label(address(target), "xFnReentrancy_contract");
        vm.label(address(attacker), "Attacker_contract");

        // Initial funding
        deal(alice, 10 ether);
        deal(bob, 10 ether);
        deal(carol, 10 ether);
        deal(mallory, 10 ether);

        // Initial depositting
        vm.prank(alice);
        target.deposit{value: 10 ether}();
        vm.prank(bob);
        target.deposit{value: 10 ether}();
        vm.prank(carol);
        target.deposit{value: 10 ether}();
        
    }

    function test_BasicReentrancy() public {
        // Create a new attacker contract and craft this failing test yourself :)
    } 

    function test_102_2_xFn_reentrancy() public {
        console.log("Mallory sends 10 ether to the attacker");
        vm.prank(mallory);
        attacker.exploit{value: 10 ether}();
        console2.log("Mallorie's deposit in target is %s ETH", target.userBalance(mallory)/1 ether);
        console2.log("Attacker's deposit in target is %s ETH", target.userBalance(address(attacker))/1 ether);
        assertEq(attacker.totalOwned() , 20 ether, "Exploit failed");
    }

}