// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IProtocolDataProvider {
    function getReserveTokensAddresses(address asset)
        external
        view
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        );
}
