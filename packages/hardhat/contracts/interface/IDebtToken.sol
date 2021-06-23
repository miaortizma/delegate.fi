// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IDebtToken {
    function approveDelegation(address delegatee, uint256 amount) external;

    function borrowAllowance(address fromUser, address toUser)
        external
        view
        returns (uint256);
}
