// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface ISuperToken {
    function upgradeTo(address to, uint256 amount, bytes calldata data) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function approve(address recipient, uint256 amount) external;

    function upgrade(uint256 amount) external;

    function balanceOf(address account) external view returns(uint256 balance);
}