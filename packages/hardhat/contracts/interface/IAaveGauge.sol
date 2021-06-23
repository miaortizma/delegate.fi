// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IAaveGauge {
    function claim_rewards(address _addr) external;

    function deposit(uint256 _value) external;

    function withdraw(uint256 _value) external;

    function balanceOf(address _addr) external view returns (uint256);
}