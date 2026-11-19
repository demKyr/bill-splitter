// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "./interfaces/IBillSplitter.sol";
import {BillSplitterBase} from "./BillSplitterBase.sol";

/// @title Bill splitter, Part 1: requests
/// @notice Behaviour comes from Part 1 of docs/SPEC_CONTRACTS.md.
/// @dev Requests are created, stored and read. Each participant's share is stored at creation (R21).
abstract contract Requests is BillSplitterBase {
    /// @dev Basis points in 100 percent (R15).
    uint256 internal constant FULL_PERCENTAGE = 10000;

    /// @dev Request ID => participant => share, stored when the request is created (R21).
    mapping(uint256 requestId => mapping(address participant => uint256)) internal _shares;

    /// @inheritdoc IBillSplitter
    /// @dev An equal split (R14): checks in the order of R13.
    function createRequest(uint256 amount, address[] calldata participants) external returns (uint256 requestId) {
        _checkAmount(amount);
        _checkParticipantCount(participants);
        _checkEachParticipant(participants);

        requestId = _storeRequest(amount, participants);
        _storeEqualShares(requestId, amount, participants);
    }

    /// @inheritdoc IBillSplitter
    /// @dev Checks in the order of R20.
    function createRequestByPercentage(uint256 amount, address[] calldata participants, uint256[] calldata percentages)
        external
        returns (uint256 requestId)
    {
        _checkAmount(amount);
        _checkPercentageAmount(amount);
        _checkParticipantCount(participants);
        _checkLength(participants, percentages);
        _checkEachParticipant(participants);
        _checkNoZero(percentages);
        _checkSum(percentages, FULL_PERCENTAGE);

        requestId = _storeRequest(amount, participants);
        _storePercentageShares(requestId, amount, participants, percentages);
    }

    /// @inheritdoc IBillSplitter
    /// @dev Checks in the order of R20.
    function createRequestByAmounts(uint256 amount, address[] calldata participants, uint256[] calldata amounts)
        external
        returns (uint256 requestId)
    {
        _checkAmount(amount);
        _checkParticipantCount(participants);
        _checkLength(participants, amounts);
        _checkEachParticipant(participants);
        _checkNoZero(amounts);
        _checkSum(amounts, amount);

        requestId = _storeRequest(amount, participants);
        _storeExactShares(requestId, participants, amounts);
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
    /// @dev R21: the share stored at creation. Zero for an address that is not a participant (R8).
    function shareOf(uint256 requestId, address participant) public view returns (uint256) {
        _existingRequest(requestId);
        return _shares[requestId][participant];
    }

    // ---------------------------------------------------------------- storing

    /// @dev R1, R6: stores the request with the caller as requester and returns its new ID.
    function _storeRequest(uint256 amount, address[] calldata participants) internal returns (uint256 requestId) {
        requestId = ++_requestCount;
        _requests[requestId] = Request({requester: msg.sender, amount: amount, participants: participants});
        emit RequestCreated(requestId, msg.sender, amount, participants);
    }

    /// @dev R7, R11: each participant owes the amount divided by their number, rounded up.
    function _storeEqualShares(uint256 requestId, uint256 amount, address[] calldata participants) internal {
        uint256 share = _ceilDiv(amount, participants.length);
        for (uint256 i = 0; i < participants.length; i++) {
            _shares[requestId][participants[i]] = share;
        }
    }

    /// @dev R17: amount * percentage / 10000, rounded up. R22 and R16 keep the product in range.
    function _storePercentageShares(
        uint256 requestId,
        uint256 amount,
        address[] calldata participants,
        uint256[] calldata percentages
    ) internal {
        for (uint256 i = 0; i < participants.length; i++) {
            _shares[requestId][participants[i]] = _ceilDiv(amount * percentages[i], FULL_PERCENTAGE);
        }
    }

    /// @dev R18: each participant owes its own amount.
    function _storeExactShares(uint256 requestId, address[] calldata participants, uint256[] calldata amounts)
        internal
    {
        for (uint256 i = 0; i < participants.length; i++) {
            _shares[requestId][participants[i]] = amounts[i];
        }
    }

    /// @dev `amount / n`, rounded up to the next whole wei (R7, R11, R17). Cannot overflow.
    function _ceilDiv(uint256 amount, uint256 n) internal pure returns (uint256) {
        return amount / n + (amount % n == 0 ? 0 : 1);
    }

    // ---------------------------------------------------------------- checks

    /// @dev R2: rejects a zero amount.
    function _checkAmount(uint256 amount) internal pure {
        if (amount == 0) revert BillSplitter__InvalidAmount(amount);
    }

    /// @dev R22: rejects a percentage-split amount above type(uint256).max / 10000.
    function _checkPercentageAmount(uint256 amount) internal pure {
        if (amount > type(uint256).max / FULL_PERCENTAGE) revert BillSplitter__InvalidAmount(amount);
    }

    /// @dev R3: 1 to MAX_PARTICIPANTS participants.
    function _checkParticipantCount(address[] calldata participants) internal pure {
        uint256 count = participants.length;
        if (count == 0 || count > MAX_PARTICIPANTS) revert BillSplitter__InvalidParticipants();
    }

    /// @dev R4, R5: in list order, rejects the zero address and a repeated address.
    function _checkEachParticipant(address[] calldata participants) internal pure {
        for (uint256 i = 0; i < participants.length; i++) {
            address participant = participants[i];
            if (participant == address(0)) revert BillSplitter__InvalidParticipant(participant);
            for (uint256 j = 0; j < i; j++) {
                if (participants[j] == participant) revert BillSplitter__InvalidParticipant(participant);
            }
        }
    }

    /// @dev R20: one percentage or amount for each participant.
    function _checkLength(address[] calldata participants, uint256[] calldata values) internal pure {
        if (values.length != participants.length) revert BillSplitter__InvalidShares();
    }

    /// @dev R19: rejects a percentage or an amount of zero.
    function _checkNoZero(uint256[] calldata values) internal pure {
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == 0) revert BillSplitter__InvalidShares();
        }
    }

    /// @dev R16, R18: the values add up to exactly `expected`. A sum that would overflow is not `expected`.
    function _checkSum(uint256[] calldata values, uint256 expected) internal pure {
        uint256 total = 0;
        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] > expected - total) revert BillSplitter__InvalidShares();
            total += values[i];
        }
        if (total != expected) revert BillSplitter__InvalidShares();
    }
}
