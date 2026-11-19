// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice Fuzz test for shareOf, rules R7, R8 and R11 of docs/SPEC_CONTRACTS.md.
contract ShareOfFuzzTest is Test {
    IBillSplitter internal splitter;

    address internal alice = makeAddr("alice");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        splitter = new BillSplitter();
    }

    /// R7, R8, R11: every participant owes the same share, the shares cover the amount
    /// with less than n wei extra, and a non-participant owes nothing.
    function testFuzz_ShareOf(uint256 amount, uint256 n) public {
        amount = bound(amount, 1, type(uint256).max);
        n = bound(n, 1, 10);

        address[] memory participants = _participants(n);
        vm.prank(alice);
        uint256 id = splitter.createRequest(amount, participants);

        uint256 share = splitter.shareOf(id, participants[0]);
        for (uint256 i = 1; i < n; i++) {
            assertEq(splitter.shareOf(id, participants[i]), share, "shares differ");
        }

        _assertCoversAmount(share, n, amount);
        assertEq(splitter.shareOf(id, stranger), 0, "non-participant share");
    }

    /// @dev Checks amount <= share * n < amount + n without computing either side,
    /// since both can overflow. Write amount = q * n + r with 0 <= r < n. Then
    /// share * n - amount = (share - q) * n - r, so the check is r <= (share - q) * n < r + n.
    /// That needs share - q to be 0 or 1, so the product stays small.
    function _assertCoversAmount(uint256 share, uint256 n, uint256 amount) internal pure {
        uint256 q = amount / n;
        uint256 r = amount % n;
        assertGe(share, q, "share * n < amount");
        assertLe(share - q, 1, "share * n >= amount + n");
        uint256 excessPlusR = (share - q) * n;
        assertGe(excessPlusR, r, "share * n < amount");
        assertLt(excessPlusR, r + n, "share * n >= amount + n");
    }

    /// @dev `n` distinct, nonzero addresses, none equal to `stranger`.
    function _participants(uint256 n) internal returns (address[] memory participants) {
        participants = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            participants[i] = makeAddr(string.concat("participant", vm.toString(i)));
        }
    }
}
