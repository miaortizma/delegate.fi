pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interface/ILendingPool.sol";
import "./interface/IDebtToken.sol";
import "./interface/IProtocolDataProvider.sol";

contract DelegateCreditManager is Ownable {
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
  mapping(address => uint256) public totalDelegatedAmounts;

  constructor(ILendingPool _lendingPool, IProtocolDataProvider _provider) {
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
    
    DelegatorInfo storage delegator = delegators[msg.sender];

    if (_amount > delegator.amountDelegated) {
      uint256 diffAllowance = _amount.sub(delegator.amountDelegated);

      totalDelegatedAmounts[_asset].add(diffAllowance);
    } else {
      uint256 diffAllowance = delegator.amountDelegated.sub(_amount);

      totalDelegatedAmounts[_asset].sub(diffAllowance);
    }
    
    // no need for sub || add operation, as approveDelegation auto-updates either increasing or decreasing allowance
    delegator.amountDelegated = _amount;
  }

  function deployCapital(address _asset) external onlyOwner {
    uint256 capitalAvailable = totalDelegatedAmounts[_asset];
    
    // 1. Check which strategy is available working with this kind of asset

    // 2. Check how much has been deployed in the strategies

    // 3. Grab the difference between the total available and deployed

    // 4. Borrow the difference from the lendingPool of AAVE

    // 5. Deposit on the strategy!
  }

  function borrowablePowerAvailable() internal view returns (uint256) {
    (, , uint256 availableBorrowsETH, , ,  ) = lendingPool.getUserAccountData(address(this));

    return availableBorrowsETH;
  }
}
