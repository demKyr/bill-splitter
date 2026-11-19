// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {IBillSplitter} from "./interfaces/IBillSplitter.sol";
import {BillSplitterBase} from "./BillSplitterBase.sol";

/// @title Bill splitter: withdrawals
/// @notice A requester takes out the ETH that participants paid. Already written.
abstract contract Withdrawals is BillSplitterBase {
    /// @inheritdoc IBillSplitter
    function withdrawable(address requester) external view returns (uint256) {
        return _withdrawable[requester];
    }

    /// @inheritdoc IBillSplitter
    function withdraw() external {
        uint256 amount = _withdrawable[msg.sender];
        if (amount == 0) revert BillSplitter__NothingToWithdraw();

        (bool sent,) = msg.sender.call{value: amount}("");
        if (!sent) revert BillSplitter__TransferFailed();

        _withdrawable[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
    }
}
