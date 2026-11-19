// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "./interfaces/IBillSplitter.sol";
import {Requests} from "./Requests.sol";

/// @title Bill splitter, Part 2: payments
/// @notice Part 2 is optional. Behaviour comes from Part 2 of docs/SPEC_CONTRACTS.md.
abstract contract Payments is Requests {
    /// @inheritdoc IBillSplitter
    /// @dev Checks in the order of P8: request ID, participant, second payment, amount.
    function pay(uint256 requestId) external payable {
        Request storage request = _existingRequest(requestId);
        _requireParticipant(request, requestId, msg.sender);
        _requireNotPaid(requestId, msg.sender);
        _requireExactShare(requestId, msg.sender, msg.value);

        _hasPaid[requestId][msg.sender] = true;
        _withdrawable[request.requester] += msg.value;
        emit SharePaid(requestId, msg.sender, msg.value);
    }

    /// @inheritdoc IBillSplitter
    function hasPaid(uint256 requestId, address participant) external view returns (bool) {
        Request storage request = _existingRequest(requestId);
        _requireParticipant(request, requestId, participant);
        return _hasPaid[requestId][participant];
    }

    /// @dev P4, P7: reverts with BillSplitter__NotParticipant for an address that is not a participant.
    function _requireParticipant(Request storage request, uint256 requestId, address account) internal view {
        if (!_isParticipant(request, account)) revert BillSplitter__NotParticipant(requestId, account);
    }

    /// @dev P3: reverts with BillSplitter__AlreadyPaid for a second payment.
    function _requireNotPaid(uint256 requestId, address participant) internal view {
        if (_hasPaid[requestId][participant]) revert BillSplitter__AlreadyPaid(requestId, participant);
    }

    /// @dev P2, P9: reverts with BillSplitter__WrongPayment unless the payment equals the share.
    function _requireExactShare(uint256 requestId, address participant, uint256 sent) internal view {
        uint256 share = shareOf(requestId, participant);
        if (sent != share) revert BillSplitter__WrongPayment(share, sent);
    }

    function _isParticipant(Request storage request, address account) internal view returns (bool) {
        uint256 count = request.participants.length;
        for (uint256 i = 0; i < count; i++) {
            if (request.participants[i] == account) return true;
        }
        return false;
    }
}
