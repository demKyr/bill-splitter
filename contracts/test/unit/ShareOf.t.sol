// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Unit tests for shareOf and request validation, rules of docs/SPEC_CONTRACTS.md.
contract ShareOfTest is Test {
    IBillSplitter internal splitter;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");

    function setUp() public {
        splitter = new BillSplitter();
    }

    function _three() internal view returns (address[] memory participants) {
        participants = new address[](3);
        (participants[0], participants[1], participants[2]) = (bob, carol, dave);
    }

    /// R11: an uneven amount rounds up, and does not overflow for the largest amount.
    function test_R11_UnevenShareRoundsUpWithoutOverflow() public {
        vm.startPrank(alice);
        uint256 small = splitter.createRequest(1, _three());
        uint256 large = splitter.createRequest(type(uint256).max, _three());
        vm.stopPrank();

        assertEq(splitter.shareOf(small, bob), 1);
        assertEq(splitter.shareOf(small, dave), 1);
        // type(uint256).max is divisible by 3, so use 2 participants for an uneven max.
        address[] memory two = new address[](2);
        (two[0], two[1]) = (bob, carol);
        vm.prank(alice);
        uint256 largeUneven = splitter.createRequest(type(uint256).max, two);

        assertEq(splitter.shareOf(large, carol), type(uint256).max / 3);
        assertEq(splitter.shareOf(largeUneven, bob), type(uint256).max / 2 + 1);
    }

    /// R12: the requester can be a participant and owes a share like the others.
    function test_R12_RequesterAsParticipantOwesShare() public {
        address[] memory participants = new address[](3);
        (participants[0], participants[1], participants[2]) = (alice, bob, carol);
        vm.prank(alice);
        uint256 id = splitter.createRequest(3 ether, participants);

        assertEq(splitter.shareOf(id, alice), 1 ether);
        assertEq(splitter.shareOf(id, bob), 1 ether);
    }

    /// R2: a zero amount is rejected.
    function test_R2_RejectsZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidAmount.selector, 0));
        splitter.createRequest(0, _three());
    }

    /// R3: an empty participant list is rejected.
    function test_R3_RejectsEmptyParticipants() public {
        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidParticipants.selector);
        splitter.createRequest(1 ether, new address[](0));
    }

    /// R13: a request that breaks several rules reverts with the error of the first rule it breaks.
    function test_R13_ErrorOrder() public {
        vm.startPrank(alice);

        // Amount (R2) before number of participants (R3).
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidAmount.selector, 0));
        splitter.createRequest(0, new address[](0));

        // Number of participants (R3) before each participant (R4).
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidParticipants.selector);
        splitter.createRequest(1 ether, new address[](11));

        // List order: the zero address first (R4) before a later duplicate (R5).
        address[] memory zeroThenDuplicate = new address[](3);
        (zeroThenDuplicate[0], zeroThenDuplicate[1], zeroThenDuplicate[2]) = (address(0), bob, bob);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidParticipant.selector, address(0)));
        splitter.createRequest(1 ether, zeroThenDuplicate);

        // List order: a duplicate first (R5) before a later zero address (R4).
        address[] memory duplicateThenZero = new address[](3);
        (duplicateThenZero[0], duplicateThenZero[1], duplicateThenZero[2]) = (bob, bob, address(0));
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidParticipant.selector, bob));
        splitter.createRequest(1 ether, duplicateThenZero);

        vm.stopPrank();
    }

    /// R10: shareOf rejects an unknown request ID.
    function test_R10_ShareOfRejectsUnknownId() public {
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__RequestNotFound.selector, 1));
        splitter.shareOf(1, bob);
    }
}
