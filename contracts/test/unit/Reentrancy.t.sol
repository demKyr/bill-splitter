// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Test} from "forge-std/Test.sol";
import {BillSplitter} from "../../src/BillSplitter.sol";
import {IBillSplitter} from "../../src/interfaces/IBillSplitter.sol";

/// @notice A requester contract that re-enters withdraw() from receive().
contract ReentrantRequester {
    IBillSplitter internal immutable SPLITTER;
    bool public reentryBlocked;

    constructor(IBillSplitter splitter) {
        SPLITTER = splitter;
    }

    function createRequest(uint256 amount, address[] calldata participants) external returns (uint256) {
        return SPLITTER.createRequest(amount, participants);
    }

    function attack() external {
        SPLITTER.withdraw();
    }

    receive() external payable {
        // Re-enter while the splitter still holds enough ETH for another payout.
        // Catch a rejected re-entry so that the outer withdrawal still completes.
        if (address(SPLITTER).balance >= msg.value) {
            try SPLITTER.withdraw() {}
            catch {
                reentryBlocked = true;
            }
        }
    }
}

/// @notice Reentrancy on withdraw(): a requester must not take ETH that belongs to another requester.
contract ReentrancyTest is Test {
    BillSplitter internal splitter;
    ReentrantRequester internal attacker;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    function setUp() public {
        splitter = new BillSplitter();
        attacker = new ReentrantRequester(splitter);

        // Alice (honest) is owed 2 ETH by carol; the attacker is owed 1 ETH by bob.
        address[] memory toCarol = new address[](1);
        toCarol[0] = carol;
        vm.prank(alice);
        uint256 aliceRequest = splitter.createRequest(2 ether, toCarol);

        address[] memory toBob = new address[](1);
        toBob[0] = bob;
        uint256 attackerRequest = attacker.createRequest(1 ether, toBob);

        vm.deal(carol, 2 ether);
        vm.prank(carol);
        splitter.pay{value: 2 ether}(aliceRequest);

        vm.deal(bob, 1 ether);
        vm.prank(bob);
        splitter.pay{value: 1 ether}(attackerRequest);
    }

    function test_ReentrantWithdrawCannotDrainOtherRequester() public {
        attacker.attack();

        // The re-entrant withdraw() was rejected: the attacker got only its own 1 ETH.
        assertTrue(attacker.reentryBlocked());
        assertEq(address(attacker).balance, 1 ether);
        assertEq(splitter.withdrawable(address(attacker)), 0);

        // Alice's 2 ETH is still there, and she can withdraw it.
        assertEq(splitter.withdrawable(alice), 2 ether);
        vm.prank(alice);
        splitter.withdraw();
        assertEq(alice.balance, 2 ether);
        assertEq(address(splitter).balance, 0);
    }
}
