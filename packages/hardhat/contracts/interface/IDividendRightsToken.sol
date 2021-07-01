// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IDividendRightsToken {
    function issue(address beneficiary, uint256 amount) external;

    function burn(address account, uint256 amount) external;

    function distribute(uint256 cashAmount) external;
}
