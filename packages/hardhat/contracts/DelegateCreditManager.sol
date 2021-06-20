pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/ILendingPool.sol";
import "./interface/IDebtToken.sol";
import "./interface/IProtocolDataProvider.sol";
import "./interface/IStrategy.sol";

contract DelegateCreditManager is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  
  struct DelegatorInfo {
    uint256 amountDelegated;
    uint256 earnings;
    uint256 amountDeployed;
  }

  ILendingPool lendingPool;
  IProtocolDataProvider provider;
  IStrategy strategy;
  
  mapping (address => DelegatorInfo) public delegators;
  mapping(address => uint256) public totalDelegatedAmounts;

  constructor(ILendingPool _lendingPool, IProtocolDataProvider _provider) public {
    lendingPool = _lendingPool;
    provider = _provider;
  }
  
  /**
   * @dev Sets the new strategy where funds will be deployed
   * @param _strategy The new strategy address
  **/
  function setStrategy(address _strategy) external onlyOwner {
    strategy = IStrategy(address(_strategy));
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

      deployCapital(_asset, msg.sender);
    } else {
      uint256 diffAllowance = delegator.amountDelegated.sub(_amount);

      totalDelegatedAmounts[_asset].sub(diffAllowance);

      // some sort of unwinding should be added here, perhaps method called `unwind(diffAllowance, msg.sender)`, repays back debt
    }
    
    // no need for sub || add operation, as approveDelegation auto-updates either increasing or decreasing allowance
    delegator.amountDelegated = _amount;
  }

  function deployCapital(address _asset, address _delegator) internal onlyOwner {
    uint256 capitalAvailable = totalDelegatedAmounts[_asset];
    
    // 1. Check which strategy is available working with this kind of asset

    // 2. Check how much has been deployed in the strategies

    // 3. Grab the difference between the total available and deployed
    
    // 4. Borrow the difference from the lendingPool of AAVE
    DelegatorInfo storage delegator = delegators[_delegator];
    
    if (delegator.amountDelegated > delegator.amountDeployed) {
      uint256 amountToBorrow = delegator.amountDelegated.sub(delegator.amountDeployed);
      
      require(amountToBorrow > 0, "0!");

      lendingPool.borrow(_asset, amountToBorrow, 2, 0, _delegator);

      delegator.amountDeployed = delegator.amountDeployed.add(amountToBorrow);

      // 5. Deposit on the strategy!
      strategy.deposit(amountToBorrow);
    }
  }

  function borrowablePowerAvailable() internal view returns (uint256) {
    (, , uint256 availableBorrowsETH, , ,  ) = lendingPool.getUserAccountData(address(this));

    return availableBorrowsETH;
  }
}
