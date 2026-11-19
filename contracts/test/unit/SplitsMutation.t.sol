// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Tests that kill mutants of src/Requests.sol that survived the other tests (R16, R18, R20).
contract SplitsMutationTest is Test {
    IBillSplitter internal splitter;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        splitter = new BillSplitter();
    }

    function _two(uint256 a, uint256 b) internal pure returns (uint256[] memory values) {
        values = new uint256[](2);
        (values[0], values[1]) = (a, b);
    }

    /// R18: amounts whose sum overflows are rejected with InvalidShares, not with an arithmetic panic.
    function test_R18_RejectsOverflowingAmountsSum() public {
        address[] memory participants = new address[](2);
        (participants[0], participants[1]) = (bob, carol);

        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByAmounts(1, participants, _two(1, type(uint256).max));
    }

    /// R20: the amount (R22) is checked before the number of participants (R3).
    function test_R20_PercentageAmountBeforeParticipantCount() public {
        uint256 tooLarge = type(uint256).max / 10000 + 1;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidAmount.selector, tooLarge));
        splitter.createRequestByPercentage(tooLarge, new address[](0), _two(5000, 5000));
    }

    /// R20: in an exact split, the number of participants (R3) is checked before the length.
    function test_R20_AmountsParticipantCountBeforeLength() public {
        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidParticipants.selector);
        splitter.createRequestByAmounts(1 ether, new address[](0), _two(0.5 ether, 0.5 ether));
    }

    /// R20: in a percentage split, the length is checked before each participant (R4).
    function test_R20_PercentageLengthBeforeEachParticipant() public {
        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
        splitter.createRequestByPercentage(1 ether, new address[](3), _two(5000, 5000));
    }

    /// R20: in an exact split, each participant (R4) is checked before each amount (R19).
    function test_R20_AmountsEachParticipantBeforeEachAmount() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IBillSplitter.BillSplitter__InvalidParticipant.selector, address(0)));
        splitter.createRequestByAmounts(1 ether, new address[](2), _two(0, 0));
    }
}
