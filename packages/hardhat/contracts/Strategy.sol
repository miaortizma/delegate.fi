pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Strategy is Ownable {
  using SafeERC20 for IERC20;

  address public delegateFund;
  address public want; // it could DAI, USDC or USDT

  uint256 public constant MAX_FEE = 10000;
  uint256 public REVENUE_FEE = 1000;

  constructor(address[2] memory _initialConfig) {
    delegateFund = _initialConfig[0];
    want = _initialConfig[1];
  }
  
  /// --- View Functions ---

  function getName() external pure returns (string memory) {
    return "StrategyAaveCurve";
  }

  /// @notice Idle want in strat
  function balanceOfWant() public view returns (uint256) {
    return IERC20(want).balanceOf(address(this));
  }
  
  /** 
  * @dev Set fee
  * @param _revenueFee Set new revenue fee, max 15%
  **/
  function setRevenueFee(uint256 _revenueFee) external onlyOwner {
    require(_revenueFee <= 1500, "too_high!");
    REVENUE_FEE = _revenueFee;
  }
}
