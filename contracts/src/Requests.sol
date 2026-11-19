// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "./interfaces/IBillSplitter.sol";
import {BillSplitterBase} from "./BillSplitterBase.sol";

/// @title Bill splitter, Part 1: requests
/// @notice Behaviour comes from Part 1 of docs/SPEC_CONTRACTS.md.
/// @dev Requests are created, stored and read. `shareOf` is a TODO: replace its body completely.
abstract contract Requests is BillSplitterBase {
    /// @inheritdoc IBillSplitter
    function createRequest(uint256 amount, address[] calldata participants) external returns (uint256 requestId) {
        if (amount == 0) revert BillSplitter__InvalidAmount(amount);
        _checkParticipants(participants);

        requestId = ++_requestCount;
        _requests[requestId] = Request({requester: msg.sender, amount: amount, participants: participants});
        emit RequestCreated(requestId, msg.sender, amount, participants);
    }

    /// @inheritdoc IBillSplitter
    function requestCount() external view returns (uint256) {
        return _requestCount;
    }

    /// @inheritdoc IBillSplitter
    function getRequest(uint256 requestId) external view returns (address, uint256, address[] memory) {
        Request storage request = _existingRequest(requestId);
        return (request.requester, request.amount, request.participants);
    }

    /// @inheritdoc IBillSplitter
    function shareOf(uint256 requestId, address participant) public view returns (uint256) {
        Request storage request = _existingRequest(requestId);
        if (!_includes(request.participants, participant)) return 0;
        return _ceilDiv(request.amount, request.participants.length);
    }

    /// @dev Whether `account` is in `participants` (R8).
    function _includes(address[] storage participants, address account) internal view returns (bool) {
        uint256 count = participants.length;
        for (uint256 i = 0; i < count; i++) {
            if (participants[i] == account) return true;
        }
        return false;
    }

    /// @dev `amount / n`, rounded up to the next whole wei (R7, R11). Cannot overflow.
    function _ceilDiv(uint256 amount, uint256 n) internal pure returns (uint256) {
        return amount / n + (amount % n == 0 ? 0 : 1);
    }

    function _checkParticipants(address[] calldata participants) internal pure {
        uint256 count = participants.length;
        if (count == 0 || count > MAX_PARTICIPANTS) revert BillSplitter__InvalidParticipants();
        for (uint256 i = 0; i < count; i++) {
            address participant = participants[i];
            if (participant == address(0)) revert BillSplitter__InvalidParticipant(participant);
            for (uint256 j = 0; j < i; j++) {
                if (participants[j] == participant) revert BillSplitter__InvalidParticipant(participant);
            }
        }
    }
}
