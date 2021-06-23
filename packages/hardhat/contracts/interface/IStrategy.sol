// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IStrategy {
    function deposit(uint256 _amount) external;

    function withdraw(address _recipient, uint256 _amount) external;
}
