// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Fuzz tests for percentage and exact splits, rules R16 to R20 and R22 of docs/SPEC_CONTRACTS.md.
contract SplitsFuzzTest is Test {
    uint256 internal constant BASIS_POINTS = 10000;

    IBillSplitter internal splitter;

    address internal alice = makeAddr("alice");

    function setUp() public {
        splitter = new BillSplitter();
    }

    // ------------------------------------------------------------ valid splits

    /// R17: each percentage share is amount * percentage / 10000, rounded up.
    function testFuzz_PercentageShares(uint256 amount, uint256 n, uint256 seed) public {
        amount = bound(amount, 1, type(uint256).max / BASIS_POINTS);
        n = bound(n, 1, 10);
        address[] memory participants = _participants(n);
        uint256[] memory percentages = _partition(BASIS_POINTS, n, seed);

        vm.prank(alice);
        uint256 id = splitter.createRequestByPercentage(amount, participants, percentages);

        for (uint256 i = 0; i < n; i++) {
            assertEq(splitter.shareOf(id, participants[i]), _ceilBasisPoints(amount, percentages[i]), "share");
        }
    }

    /// R18: each exact share is its amount, and the shares add up to the amount.
    function testFuzz_ExactShares(uint256 amount, uint256 n, uint256 seed) public {
        amount = bound(amount, 1, type(uint256).max);
        n = bound(n, 1, amount < 10 ? amount : 10);
        address[] memory participants = _participants(n);
        uint256[] memory amounts = _partition(amount, n, seed);

        vm.prank(alice);
        uint256 id = splitter.createRequestByAmounts(amount, participants, amounts);

        uint256 total = 0;
        for (uint256 i = 0; i < n; i++) {
            uint256 share = splitter.shareOf(id, participants[i]);
            assertEq(share, amounts[i], "share");
            total += share;
        }
        assertEq(total, amount, "total");
    }

    // ------------------------------------------------------------ rejected splits

    /// R16: percentages whose sum is off by one are rejected.
    function testFuzz_RejectsPercentagesOffByOne(uint256 amount, uint256 n, uint256 seed, bool up) public {
        amount = bound(amount, 1, type(uint256).max / BASIS_POINTS);
        n = bound(n, 1, 10);
        uint256[] memory percentages = _offByOne(_partition(BASIS_POINTS, n, seed), seed, up);

        _expectInvalidShares();
        splitter.createRequestByPercentage(amount, _participants(n), percentages);
    }

    /// R18: amounts whose sum is off by one are rejected.
    function testFuzz_RejectsAmountsOffByOne(uint256 amount, uint256 n, uint256 seed, bool up) public {
        amount = bound(amount, 1, type(uint256).max - 1);
        n = bound(n, 1, amount < 10 ? amount : 10);
        // With every part equal to 1, the sum can only go up without making a zero.
        if (amount == n) up = true;
        uint256[] memory amounts = _offByOne(_partition(amount, n, seed), seed, up);

        _expectInvalidShares();
        splitter.createRequestByAmounts(amount, _participants(n), amounts);
    }

    /// R19: a zero percentage is rejected.
    function testFuzz_RejectsZeroPercentage(uint256 amount, uint256 n, uint256 seed, uint256 index) public {
        amount = bound(amount, 1, type(uint256).max / BASIS_POINTS);
        n = bound(n, 1, 10);
        uint256[] memory percentages = _partition(BASIS_POINTS, n, seed);
        percentages[bound(index, 0, n - 1)] = 0;

        _expectInvalidShares();
        splitter.createRequestByPercentage(amount, _participants(n), percentages);
    }

    /// R19: a zero amount is rejected.
    function testFuzz_RejectsZeroAmount(uint256 amount, uint256 n, uint256 seed, uint256 index) public {
        amount = bound(amount, 1, type(uint256).max);
        n = bound(n, 1, amount < 10 ? amount : 10);
        uint256[] memory amounts = _partition(amount, n, seed);
        amounts[bound(index, 0, n - 1)] = 0;

        _expectInvalidShares();
        splitter.createRequestByAmounts(amount, _participants(n), amounts);
    }

    /// R20: a list of percentages with a different length than the participants is rejected,
    /// even when the percentages add up to 10000.
    function testFuzz_RejectsPercentagesWrongLength(uint256 amount, uint256 n, uint256 m, uint256 seed) public {
        amount = bound(amount, 1, type(uint256).max / BASIS_POINTS);
        n = bound(n, 1, 10);
        m = _otherLength(n, m);

        _expectInvalidShares();
        splitter.createRequestByPercentage(amount, _participants(n), _partition(BASIS_POINTS, m, seed));
    }

    /// R20: a list of amounts with a different length than the participants is rejected,
    /// even when the amounts add up to the amount.
    function testFuzz_RejectsAmountsWrongLength(uint256 amount, uint256 n, uint256 m, uint256 seed) public {
        amount = bound(amount, 11, type(uint256).max);
        n = bound(n, 1, 10);
        m = _otherLength(n, m);

        _expectInvalidShares();
        splitter.createRequestByAmounts(amount, _participants(n), _partition(amount, m, seed));
    }

    // ------------------------------------------------------------ helpers

    function _expectInvalidShares() internal {
        vm.prank(alice);
        vm.expectRevert(IBillSplitter.BillSplitter__InvalidShares.selector);
    }

    /// @dev ceil(amount * percentage / 10000). The product cannot overflow because
    /// amount <= type(uint256).max / 10000 and percentage <= 10000. Adding 9999 before
    /// dividing could overflow, so round up with the remainder instead.
    function _ceilBasisPoints(uint256 amount, uint256 percentage) internal pure returns (uint256) {
        uint256 product = amount * percentage;
        return product / BASIS_POINTS + (product % BASIS_POINTS == 0 ? 0 : 1);
    }

    /// @dev `m` random positive parts that add up to `total`. Needs total >= m. Empty for m == 0.
    function _partition(uint256 total, uint256 m, uint256 seed) internal pure returns (uint256[] memory parts) {
        parts = new uint256[](m);
        if (m == 0) return parts;
        uint256 remaining = total;
        for (uint256 i = 0; i < m - 1; i++) {
            // Leave at least 1 for each later part.
            uint256 maxPart = remaining - (m - 1 - i);
            uint256 rand = uint256(keccak256(abi.encode(seed, i)));
            parts[i] = 1 + rand % maxPart;
            remaining -= parts[i];
        }
        parts[m - 1] = remaining;
    }

    /// @dev Adds 1 to a random part, or subtracts 1 from a random part greater than 1.
    /// Subtracting needs some part greater than 1.
    function _offByOne(uint256[] memory parts, uint256 seed, bool up) internal pure returns (uint256[] memory) {
        uint256 m = parts.length;
        uint256 start = uint256(keccak256(abi.encode(seed, "index"))) % m;
        for (uint256 k = 0; k < m; k++) {
            uint256 i = (start + k) % m;
            if (up) {
                parts[i] += 1;
                return parts;
            }
            if (parts[i] > 1) {
                parts[i] -= 1;
                return parts;
            }
        }
        revert("no part greater than 1");
    }

    /// @dev A length from 0 to 11 that is not `n`.
    function _otherLength(uint256 n, uint256 m) internal pure returns (uint256) {
        m = bound(m, 0, 10);
        return m >= n ? m + 1 : m;
    }

    /// @dev `n` distinct, nonzero addresses.
    function _participants(uint256 n) internal returns (address[] memory participants) {
        participants = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            participants[i] = makeAddr(string.concat("participant", vm.toString(i)));
        }
    }
}
