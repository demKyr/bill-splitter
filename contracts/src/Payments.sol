// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "./interfaces/IBillSplitter.sol";
import {Requests} from "./Requests.sol";

/// @title Bill splitter, Part 2: payments
/// @notice Part 2 is optional. Behaviour comes from Part 2 of docs/SPEC_CONTRACTS.md.
/// @dev Partly written. `pay` checks the payer and the amount, and credits the requester.
///      `hasPaid` is a TODO: replace its body completely.
abstract contract Payments is Requests {
    /// @inheritdoc IBillSplitter
    function pay(uint256 requestId) external payable {
        Request storage request = _existingRequest(requestId);
        if (!_isParticipant(request, msg.sender)) revert BillSplitter__NotParticipant(requestId, msg.sender);

        uint256 share = shareOf(requestId, msg.sender);
        if (msg.value < share) revert BillSplitter__WrongPayment(share, msg.value);

        _withdrawable[request.requester] += msg.value;
        emit SharePaid(requestId, msg.sender, msg.value);
    }

    /// @inheritdoc IBillSplitter
    function hasPaid(uint256 requestId, address) external view returns (bool) {
        _existingRequest(requestId);
        // TODO: whether this participant has paid its share of the request.
        revert BillSplitter__NotImplemented();
    }

    function _isParticipant(Request storage request, address account) internal view returns (bool) {
        uint256 count = request.participants.length;
        for (uint256 i = 0; i < count; i++) {
            if (request.participants[i] == account) return true;
        }
        return false;
    }
}
