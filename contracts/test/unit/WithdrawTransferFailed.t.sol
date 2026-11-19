// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice A requester contract that cannot receive ETH: it has no receive() or fallback().
contract RejectingRequester {
    IBillSplitter internal immutable SPLITTER;

    constructor(IBillSplitter splitter) {
        SPLITTER = splitter;
    }

    function createRequest(uint256 amount, address[] calldata participants) external returns (uint256) {
        return SPLITTER.createRequest(amount, participants);
    }

    function withdraw() external {
        SPLITTER.withdraw();
    }
}

/// @notice P6: a withdrawal whose ETH transfer fails must revert and keep the requester's balance.
contract WithdrawTransferFailedTest is Test {
    BillSplitter internal splitter;
    RejectingRequester internal requester;
    address internal payer = makeAddr("payer");

    function setUp() public {
        splitter = new BillSplitter();
        requester = new RejectingRequester(splitter);
        vm.deal(payer, 1 ether);
    }

    function test_P6_FailedTransferRevertsAndKeepsBalance() public {
        address[] memory participants = new address[](1);
        participants[0] = payer;
        uint256 id = requester.createRequest(1 ether, participants);
        vm.prank(payer);
        splitter.pay{value: 1 ether}(id);

        vm.expectRevert(IBillSplitter.BillSplitter__TransferFailed.selector);
        requester.withdraw();

        assertEq(splitter.withdrawable(address(requester)), 1 ether);
        assertEq(address(splitter).balance, 1 ether);
    }
}
