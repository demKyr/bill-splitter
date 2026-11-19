// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import {Payments} from "./Payments.sol";
import {Withdrawals} from "./Withdrawals.sol";

/// @title Bill splitter
/// @notice The contract that is deployed. It only joins the parts. Complete: do not edit.
/// @dev Requests.sol (Part 1), Payments.sol (Part 2) and Withdrawals.sol hold the behaviour.
contract BillSplitter is Payments, Withdrawals {}
