pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/102/1-pushPull.sol";

contract PPtest is Test  {
    PullOverPush public target;
    Attacker public attacker;

    address alice = address(0x1);
    address bob = address(0x2);
    address carol = address(0x3);

    function setUp() public {
        //addresses
        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(carol, "Carol");

        target = new PullOverPush();
        attacker = new Attacker(payable(address(target)));
        vm.label(address(target), "PullOverPush_contract");
        vm.label(address(attacker), "Attacker_contract");

        // Initial funding to trigger receive
        (bool success, ) = address(target).call{value: 40 ether}("");
        require(success);

        // Everyone takes part in the game
        
        vm.prank(alice);
        target.participate();
        vm.prank(bob);
        target.participate();
        vm.prank(carol);
        target.participate();
        attacker.joinContest();
        
    }

    function testPull() public {
        console.log("Pot is %s", target.pot());
        
        vm.prank(alice);
        target.retrieveOnePull();
        assertEq(alice.balance, 10 ether, "Pull failed");

        vm.prank(bob);
        target.retrieveOnePull();
        assertEq(bob.balance, 10 ether, "Pull failed");

        vm.prank(carol);
        target.retrieveOnePull();
        assertEq(carol.balance, 10 ether, "Pull failed");
    }

    function testPush() public {
        //vm.expectRevert(bytes("Transfer failed."));
        target.retrieveAllPush();
    }
}