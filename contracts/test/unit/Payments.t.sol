// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Unit tests for Part 2 (payments), rules of docs/SPEC_CONTRACTS.md.
contract PaymentsTest is Test {
    IBillSplitter internal splitter;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal stranger = makeAddr("stranger");
    uint256 internal id;

    function setUp() public {
        splitter = new BillSplitter();
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
        vm.deal(stranger, 10 ether);

        address[] memory participants = new address[](2);
        (participants[0], participants[1]) = (bob, carol);
        vm.prank(alice);
        id = splitter.createRequest(2 ether, participants);
    }

    /// P3: a second payment by the same participant is rejected.
    function test_P3_RejectsSecondPayment() public {
        vm.startPrank(bob);
        splitter.pay{value: 1 ether}(id);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__AlreadyPaid.selector, id, bob));
        splitter.pay{value: 1 ether}(id);
        vm.stopPrank();
    }

    /// P7: hasPaid rejects an address that is not a participant.
    function test_P7_HasPaidRejectsNonParticipant() public {
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__NotParticipant.selector, id, stranger));
        splitter.hasPaid(id, stranger);
    }

    /// P8: a payment that breaks several rules reverts with the error of the first rule it breaks.
    function test_P8_ErrorOrder() public {
        // Request ID (R10) before participant (P4).
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__RequestNotFound.selector, 99));
        splitter.pay{value: 0}(99);

        // Participant (P4) before amount (P2).
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__NotParticipant.selector, id, stranger));
        splitter.pay{value: 0}(id);

        // Second payment (P3) before amount (P2).
        vm.startPrank(bob);
        splitter.pay{value: 1 ether}(id);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__AlreadyPaid.selector, id, bob));
        splitter.pay{value: 0}(id);
        vm.stopPrank();
    }

    /// P9: a payment above the share is rejected.
    function test_P9_RejectsOverpayment() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__WrongPayment.selector, 1 ether, 2 ether));
        splitter.pay{value: 2 ether}(id);
    }

    /// P6: the requester withdraws all collected ETH in one call; a second call is rejected.
    function test_P6_WithdrawAllThenRejectsZero() public {
        vm.prank(bob);
        splitter.pay{value: 1 ether}(id);
        vm.prank(carol);
        splitter.pay{value: 1 ether}(id);

        vm.prank(alice);
        splitter.withdraw();
        assertEq(alice.balance, 2 ether);
        assertEq(splitter.withdrawable(alice), 0);
        assertEq(address(splitter).balance, 0);

        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__NothingToWithdraw.selector);
        splitter.withdraw();
    }
}
