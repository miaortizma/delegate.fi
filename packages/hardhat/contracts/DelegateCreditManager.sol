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
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPool lendingPool;
  IProtocolDataProvider provider;

  struct DelegatorInfo {
    uint256 amountDelegated;
    uint256 earnings;
  }
  mapping(address => uint256) public totalDelegatedAmounts;
  mapping(address => DelegatorInfo) public delegators;

  constructor(ILendingPool _lendingPool) {
    lendingPool = _lendingPool;
    provider = _dataProvider;
  }

  /**
   * @dev Allows user to delegate to our protocol (first point of contact user:protocol)
   * @param _asset The asset which is delegated
   * @param _amount The amount delegated to us to manage
  **/
  function delegateCreditLine(address _asset, uint256 _amount) {
    (, , address variableDebtTokenAddress) = provider.getReserveTokensAddresses(_asset);
    
    IDebtToken(variableDebtTokenAddress).approveDelegation(address(this), _amount);
    // update the total delgated amount, also update the delegators info.
    totalDelegatedAmounts[_asset].add(_amount);
    delegators[msg.sender].amountDelegated.add(_amount);
  }
}
