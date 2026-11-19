// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

/// @title Bill splitter interface
/// @notice A requester who paid a bill asks participants to pay it back in equal shares of ETH.
/// @dev This file is the agreed boundary between the contract and the web app.
///      It is fixed for the practical. Do not edit it.
///      Part 1 (everyone): requests. Part 2 (optional): payments.
interface IBillSplitter {
    // ---------------------------------------------------------------- Part 1: requests

    /// @notice Emitted when a request is created.
    event RequestCreated(uint256 indexed requestId, address indexed requester, uint256 amount, address[] participants);

    /// @notice The amount is not allowed for a request.
    error BillSplitter__InvalidAmount(uint256 amount);
    /// @notice The participant list as a whole is not allowed: it is empty or too long.
    error BillSplitter__InvalidParticipants();
    /// @notice One address in the participant list is not allowed.
    error BillSplitter__InvalidParticipant(address participant);
    /// @notice No request has this ID.
    error BillSplitter__RequestNotFound(uint256 requestId);

    /// @notice The largest number of participants in one request.
    function MAX_PARTICIPANTS() external view returns (uint256);

    /// @notice Creates a request. The caller becomes the requester.
    /// @param amount The total to collect from the participants, in wei.
    /// @param participants The addresses that share the amount.
    /// @return requestId The ID of the new request. IDs start at 1 and increase by 1.
    function createRequest(uint256 amount, address[] calldata participants) external returns (uint256 requestId);

    /// @notice The number of requests created so far. It is also the latest request ID.
    function requestCount() external view returns (uint256);

    /// @notice Reads one request. Reverts with BillSplitter__RequestNotFound for an unknown ID.
    function getRequest(uint256 requestId)
        external
        view
        returns (address requester, uint256 amount, address[] memory participants);

    /// @notice The share that `participant` owes for a request, in wei.
    ///         Zero for an address that is not a participant.
    ///         Reverts with BillSplitter__RequestNotFound for an unknown ID.
    function shareOf(uint256 requestId, address participant) external view returns (uint256);

    // ---------------------------------------------------------------- Part 2: payments (optional)

    /// @notice Emitted when a participant pays its share.
    event SharePaid(uint256 indexed requestId, address indexed participant, uint256 amount);
    /// @notice Emitted when a requester withdraws collected ETH.
    event Withdrawn(address indexed requester, uint256 amount);

    /// @notice The caller is not a participant of this request.
    error BillSplitter__NotParticipant(uint256 requestId, address caller);
    /// @notice This participant already paid its share of this request.
    error BillSplitter__AlreadyPaid(uint256 requestId, address participant);
    /// @notice The ETH sent is not an accepted payment for this share.
    error BillSplitter__WrongPayment(uint256 expected, uint256 sent);
    /// @notice The caller has no collected ETH to withdraw.
    error BillSplitter__NothingToWithdraw();
    /// @notice The ETH transfer to the caller failed.
    error BillSplitter__TransferFailed();

    /// @notice A participant pays its share of a request, with ETH sent in the call.
    ///         The contract keeps the ETH until the requester withdraws it.
    function pay(uint256 requestId) external payable;

    /// @notice Whether `participant` has paid its share of a request.
    ///         Reverts with BillSplitter__RequestNotFound for an unknown ID.
    function hasPaid(uint256 requestId, address participant) external view returns (bool);

    /// @notice The collected ETH that `requester` can withdraw, in wei.
    function withdrawable(address requester) external view returns (uint256);

    /// @notice Sends all the caller's collected ETH to the caller.
    function withdraw() external;
}
