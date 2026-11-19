// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Unit tests for percentage and exact splits, rules R16 to R22 of docs/SPEC_CONTRACTS.md.
contract SplitsTest is Test {
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

    function _values(uint256 a, uint256 b, uint256 c) internal pure returns (uint256[] memory values) {
        values = new uint256[](3);
        (values[0], values[1], values[2]) = (a, b, c);
    }

    /// R16: percentages that do not add up to 10000 are rejected.
    function test_R16_RejectsPercentagesNotSummingTo10000() public {
        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByPercentage(1 ether, _three(), _values(5000, 3000, 1999));
    }

    /// R17: a percentage share is amount * percentage / 10000, rounded up.
    function test_R17_PercentageShareRoundsUp() public {
        vm.prank(alice);
        uint256 id = splitter.createRequestByPercentage(1, _three(), _values(3333, 3333, 3334));

        // 1 * 3333 / 10000 = 0.3333, rounded up to 1 wei.
        assertEq(splitter.shareOf(id, bob), 1);
        assertEq(splitter.shareOf(id, dave), 1);
    }

    /// R17, R18: shares that add up exactly to the amount.
    function test_SharesAddUpToAmount() public {
        vm.startPrank(alice);
        uint256 byPercentage = splitter.createRequestByPercentage(10 ether, _three(), _values(5000, 3000, 2000));
        uint256 byAmounts = splitter.createRequestByAmounts(10 ether, _three(), _values(6 ether, 3 ether, 1 ether));
        vm.stopPrank();

        assertEq(splitter.shareOf(byPercentage, bob), 5 ether);
        assertEq(splitter.shareOf(byPercentage, carol), 3 ether);
        assertEq(splitter.shareOf(byPercentage, dave), 2 ether);
        assertEq(
            splitter.shareOf(byPercentage, bob) + splitter.shareOf(byPercentage, carol)
                + splitter.shareOf(byPercentage, dave),
            10 ether
        );
        assertEq(
            splitter.shareOf(byAmounts, bob) + splitter.shareOf(byAmounts, carol) + splitter.shareOf(byAmounts, dave),
            10 ether
        );
    }

    /// R18: amounts that do not add up to the request amount are rejected; a share is its amount.
    function test_R18_ExactSplit() public {
        vm.startPrank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByAmounts(10 ether, _three(), _values(6 ether, 3 ether, 2 ether));

        uint256 id = splitter.createRequestByAmounts(10 ether, _three(), _values(7, 10 ether - 8, 1));
        vm.stopPrank();

        assertEq(splitter.shareOf(id, bob), 7);
        assertEq(splitter.shareOf(id, carol), 10 ether - 8);
        assertEq(splitter.shareOf(id, dave), 1);
    }

    /// R19: a percentage or an amount of zero is rejected.
    function test_R19_RejectsZeroPercentageOrAmount() public {
        vm.startPrank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByPercentage(1 ether, _three(), _values(5000, 0, 5000));

        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByAmounts(1 ether, _three(), _values(1 ether, 0, 0));
        vm.stopPrank();
    }

    /// R20: a list of the wrong length is rejected, and errors come in the order of R20.
    function test_R20_LengthAndErrorOrder() public {
        uint256[] memory two = new uint256[](2);
        (two[0], two[1]) = (5000, 5000);

        vm.startPrank(alice);
        // Wrong length.
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByPercentage(1 ether, _three(), two);

        // Amount (R2) before everything else.
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidAmount.selector, 0));
        splitter.createRequestByAmounts(0, new address[](0), two);

        // Number of participants (R3) before length (R20).
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidParticipants.selector);
        splitter.createRequestByPercentage(1 ether, new address[](0), two);

        // Length (R20) before each participant (R4).
        address[] memory zero = new address[](3);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByAmounts(1 ether, zero, two);

        // Each participant (R4) before each percentage (R19) and the sum (R16).
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidParticipant.selector, address(0)));
        splitter.createRequestByPercentage(1 ether, zero, _values(0, 0, 0));
        vm.stopPrank();
    }

    /// R21: shareOf returns the share of the split, and zero for a non-participant.
    function test_R21_ShareOfFollowsSplit() public {
        vm.startPrank(alice);
        uint256 equal = splitter.createRequest(3 ether, _three());
        uint256 exact = splitter.createRequestByAmounts(3 ether, _three(), _values(2 ether, 0.5 ether, 0.5 ether));
        vm.stopPrank();

        assertEq(splitter.shareOf(equal, bob), 1 ether);
        assertEq(splitter.shareOf(exact, bob), 2 ether);
        assertEq(splitter.shareOf(exact, alice), 0);

        // A payment must equal the share of the split (P9).
        vm.deal(bob, 2 ether);
        vm.prank(bob);
        splitter.pay{value: 2 ether}(exact);
        assertTrue(splitter.hasPaid(exact, bob));
    }

    /// R22: a percentage-split amount above type(uint256).max / 10000 is rejected; the limit itself is accepted.
    function test_R22_RejectsTooLargePercentageAmount() public {
        uint256 limit = type(uint256).max / 10000;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidAmount.selector, limit + 1));
        splitter.createRequestByPercentage(limit + 1, _three(), _values(3333, 3333, 3334));

        uint256 id = splitter.createRequestByPercentage(limit, _three(), _values(3333, 3333, 3334));
        vm.stopPrank();

        assertEq(splitter.shareOf(id, dave), (limit * 3334 + 9999) / 10000);
    }
}
