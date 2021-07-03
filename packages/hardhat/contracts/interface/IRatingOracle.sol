// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface IRatingOracle {
    function getRating(address _borrower) external view returns (uint256);

    function getMaxLoanAmount(address _borrower)
        external
        view
        returns (uint256);

    function initiliasedCreditInfo(address _borrower) external;

    function updateCreditInfo(
        address _borrower,
        uint256 _ratingChange,
        uint256 _lastProfit,
        bool _defaulted
    ) external;
}
