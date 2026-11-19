// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "./interfaces/IBillSplitter.sol";

/// @title Bill splitter: shared state
/// @notice The state and helpers that every part of the contract uses. Complete: do not edit.
/// @dev The contract is split into one file for each part:
///        Requests.sol     Part 1, requests
///        Payments.sol     Part 2, payments (optional)
///        Withdrawals.sol  withdrawing collected ETH
///      BillSplitter.sol joins them into the contract that is deployed.
abstract contract BillSplitterBase is IBillSplitter {
    /// @dev A function that the practical leaves for you to write.
    error BillSplitter__NotImplemented();

    struct Request {
        address requester;
        uint256 amount;
        address[] participants;
    }

    uint256 public constant MAX_PARTICIPANTS = 10;

    /// @dev Request ID => request. IDs start at 1.
    mapping(uint256 requestId => Request) internal _requests;
    uint256 internal _requestCount;

    /// @dev Whether a participant has paid its share of a request.
    mapping(uint256 requestId => mapping(address participant => bool)) internal _hasPaid;
    /// @dev Collected ETH that each requester can withdraw.
    mapping(address requester => uint256) internal _withdrawable;

    /// @dev Reverts with BillSplitter__RequestNotFound for an unknown ID.
    function _existingRequest(uint256 requestId) internal view returns (Request storage request) {
        request = _requests[requestId];
        if (request.requester == address(0)) revert BillSplitter__RequestNotFound(requestId);
    }
}
