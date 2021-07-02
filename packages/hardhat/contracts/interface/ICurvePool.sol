// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

interface ICurvePool {
    function add_liquidity(uint256[3] calldata amounts, uint256 min_mint_amount)
        external;

    function remove_liquidity_one_coin(
        uint256 lp_amount,
        int128 i,
        uint256 min_amount
    ) external;

    function get_virtual_price() external view returns (uint256);
}
