// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "../interfaces/IBillSplitter.sol";

/// @title Mock bill splitter
/// @notice A stand-in that implements the interface with fixed data, so the web app can be built
///         before the real contract exists. It is not a specification: it checks no input.
/// @dev It always holds the same two requests among Anvil's default accounts:
///        Request 1: account 0 asks accounts 1, 2 and 3 for 0.3 ETH in total (0.1 ETH each). Account 1 has paid.
///        Request 2: account 1 asks accounts 0 and 2 for 0.05 ETH in total (0.025 ETH each). Nobody has paid.
///      Writes succeed and emit their event, but they store nothing.
contract MockBillSplitter is IBillSplitter {
    uint256 public constant MAX_PARTICIPANTS = 10;

    address[4] internal _accounts = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906
    ];

    function createRequest(uint256 amount, address[] calldata participants) external returns (uint256 requestId) {
        requestId = 3;
        emit RequestCreated(requestId, msg.sender, amount, participants);
    }

    function requestCount() external view returns (uint256) {
        return _accounts.length - 2;
    }

    function getRequest(uint256 requestId)
        public
        view
        returns (address requester, uint256 amount, address[] memory participants)
    {
        if (requestId == 1) {
            participants = new address[](3);
            (participants[0], participants[1], participants[2]) = (_accounts[1], _accounts[2], _accounts[3]);
            return (_accounts[0], 0.3 ether, participants);
        }
        if (requestId == 2) {
            participants = new address[](2);
            (participants[0], participants[1]) = (_accounts[0], _accounts[2]);
            return (_accounts[1], 0.05 ether, participants);
        }
        revert BillSplitter__RequestNotFound(requestId);
    }

    function shareOf(uint256 requestId, address participant) external view returns (uint256) {
        (, uint256 amount, address[] memory participants) = getRequest(requestId);
        for (uint256 i = 0; i < participants.length; i++) {
            if (participants[i] == participant) return amount / participants.length;
        }
        return 0;
    }

    function pay(uint256 requestId) external payable {
        emit SharePaid(requestId, msg.sender, msg.value);
    }

    function hasPaid(uint256 requestId, address participant) external view returns (bool) {
        getRequest(requestId);
        return requestId == 1 && participant == _accounts[1];
    }

    function withdrawable(address requester) external view returns (uint256) {
        return requester == _accounts[0] ? 0.1 ether : 0;
    }

    function withdraw() external {
        emit Withdrawn(msg.sender, 0);
    }
}
