pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interface/ILendingPool.sol";
import "./interface/IDebtToken.sol";
import "./interface/IProtocolDataProvider.sol";

contract DelegateCreditManager {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  struct DelegatorInfo {
    uint256 amountDelegated;
    uint256 earnings;
  }

  ILendingPool lendingPool;
  IProtocolDataProvider provider;
  
  // Tracks delegators info, useful more dashboards in f/e and inner accounting
  mapping (address => DelegatorInfo) public delegators;

  struct DelegatorInfo {
    uint256 amountDelegated;
    uint256 earnings;
  }
  mapping(address => uint256) public totalDelegatedAmounts;
  mapping(address => DelegatorInfo) public delegators;

  constructor(ILendingPool _lendingPool) {
    lendingPool = _lendingPool;
    provider = _provider;
  }

  /**
   * @dev Allows user to delegate to our protocol (first point of contact user:protocol)
   * @param _asset The asset which is delegated
   * @param _amount The amount delegated to us to manage
   * @notice we do not emit event as  `approveDelegation` emits -> BorrowAllowanceDelegated
  **/
  function delegateCreditLine(address _asset, uint256 _amount) external {
    (, , address variableDebtTokenAddress) = provider.getReserveTokensAddresses(_asset);
    
    IDebtToken(variableDebtTokenAddress).approveDelegation(address(this), _amount);

    // update the total delgated amount, also update the delegators info.
    totalDelegatedAmounts[_asset].add(_amount);
    
    // no need for sub || add operation, as approveDelegation auto-updates either increasing or decreasing allowance
    delegators[msg.sender].amountDelegated = _amount;

    // Do we need this temporary storage?
    // DelegatorInfo storage delegator = delegators[msg.sender];
    // delegator.amountDelegated = _amount;
  }

  function borrowablePowerAvailable() internal view returns (uint256) {
    (, , uint256 availableBorrowsETH, , ,  ) = lendingPool.getUserAccountData(address(this));

    return availableBorrowsETH;
  }
}
