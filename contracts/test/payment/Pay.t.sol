// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Ready-made tests for Part 2 (optional). They check rules of docs/SPEC_CONTRACTS.md, and the events of the interface.
///         Some fail until Part 2 is complete. Do not edit them.
contract PayTest is Test {
    IBillSplitter internal splitter;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    uint256 internal id;

    function setUp() public {
        splitter = new BillSplitter();
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);

        address[] memory participants = new address[](2);
        (participants[0], participants[1]) = (bob, carol);
        vm.prank(alice);
        id = splitter.createRequest(2 ether, participants);
    }

    function test_PayRecordsThePayment() public {
        assertFalse(splitter.hasPaid(id, bob));

        vm.prank(bob);
        splitter.pay{value: 1 ether}(id);

        assertTrue(splitter.hasPaid(id, bob));
        assertFalse(splitter.hasPaid(id, carol));
        assertEq(splitter.withdrawable(alice), 1 ether);
        assertEq(address(splitter).balance, 1 ether);
    }

    function test_PayEmitsSharePaid() public {
        vm.expectEmit(address(splitter));
        emit IBillSplitter.SharePaid(id, bob, 1 ether);
        vm.prank(bob);
        splitter.pay{value: 1 ether}(id);
    }

    function test_RevertWhen_PayerIsNotParticipant() public {
        address stranger = makeAddr("stranger");
        vm.deal(stranger, 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__NotParticipant.selector, id, stranger));
        vm.prank(stranger);
        splitter.pay{value: 1 ether}(id);
    }

    function test_RevertWhen_ParticipantPaysTwice() public {
        vm.prank(bob);
        splitter.pay{value: 1 ether}(id);

        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__AlreadyPaid.selector, id, bob));
        vm.prank(bob);
        splitter.pay{value: 1 ether}(id);
    }

    function test_RevertWhen_PayingUnknownRequest() public {
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__RequestNotFound.selector, 99));
        vm.prank(bob);
        splitter.pay{value: 1 ether}(99);
    }

    function test_RevertWhen_PaymentIsBelowTheShare() public {
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__WrongPayment.selector, 1 ether, 0.4 ether));
        vm.prank(bob);
        splitter.pay{value: 0.4 ether}(id);
    }
}
