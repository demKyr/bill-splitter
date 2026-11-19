// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Ready-made tests for Part 1. They check rules of docs/SPEC_CONTRACTS.md, and the events of the interface.
///         Do not edit them. Other tests go in test/unit/.
contract CreateRequestTest is Test {
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

    function test_MaxParticipantsIsTen() public view {
        assertEq(splitter.MAX_PARTICIPANTS(), 10);
    }

    function test_NoRequestsAtStart() public view {
        assertEq(splitter.requestCount(), 0);
    }

    function test_FirstRequestHasIdOne() public {
        vm.prank(alice);
        uint256 id = splitter.createRequest(3 ether, _three());
        assertEq(id, 1);
        assertEq(splitter.requestCount(), 1);
    }

    function test_IdsIncreaseByOne() public {
        vm.prank(alice);
        splitter.createRequest(3 ether, _three());
        vm.prank(makeAddr("erin"));
        uint256 id = splitter.createRequest(6 ether, _three());
        assertEq(id, 2);
        assertEq(splitter.requestCount(), 2);
    }

    function test_StoresTheRequest() public {
        vm.prank(alice);
        uint256 id = splitter.createRequest(3 ether, _three());

        (address requester, uint256 amount, address[] memory participants) = splitter.getRequest(id);
        assertEq(requester, alice);
        assertEq(amount, 3 ether);
        assertEq(participants, _three());
    }

    function test_EmitsRequestCreated() public {
        vm.expectEmit(address(splitter));
        emit IBillSplitter.RequestCreated(1, alice, 3 ether, _three());
        vm.prank(alice);
        splitter.createRequest(3 ether, _three());
    }

    function test_SplitsAnEvenAmountEqually() public {
        vm.prank(alice);
        uint256 id = splitter.createRequest(3 ether, _three());
        assertEq(splitter.shareOf(id, bob), 1 ether);
        assertEq(splitter.shareOf(id, carol), 1 ether);
        assertEq(splitter.shareOf(id, dave), 1 ether);
    }

    function test_ShareIsZeroForNonParticipant() public {
        vm.prank(alice);
        uint256 id = splitter.createRequest(3 ether, _three());
        assertEq(splitter.shareOf(id, makeAddr("stranger")), 0);
    }

    function test_RevertWhen_AmountIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidAmount.selector, 0));
        vm.prank(alice);
        splitter.createRequest(0, _three());
    }

    function test_RevertWhen_NoParticipants() public {
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidParticipants.selector);
        vm.prank(alice);
        splitter.createRequest(3 ether, new address[](0));
    }

    function test_RevertWhen_TooManyParticipants() public {
        address[] memory participants = new address[](11);
        for (uint256 i = 0; i < participants.length; i++) {
            participants[i] = vm.addr(i + 1);
        }
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidParticipants.selector);
        vm.prank(alice);
        splitter.createRequest(11 ether, participants);
    }

    function test_AcceptsTenParticipants() public {
        address[] memory participants = new address[](10);
        for (uint256 i = 0; i < participants.length; i++) {
            participants[i] = vm.addr(i + 1);
        }
        vm.prank(alice);
        uint256 id = splitter.createRequest(10 ether, participants);
        assertEq(splitter.shareOf(id, participants[9]), 1 ether);
    }

    function test_RevertWhen_ParticipantIsZeroAddress() public {
        address[] memory participants = _three();
        participants[1] = address(0);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidParticipant.selector, address(0)));
        vm.prank(alice);
        splitter.createRequest(3 ether, participants);
    }

    function test_RevertWhen_ParticipantIsListedTwice() public {
        address[] memory participants = _three();
        participants[2] = bob;
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidParticipant.selector, bob));
        vm.prank(alice);
        splitter.createRequest(3 ether, participants);
    }

    function test_RevertWhen_RequestDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__RequestNotFound.selector, 1));
        splitter.getRequest(1);

        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__RequestNotFound.selector, 0));
        splitter.shareOf(0, bob);
    }
}
