pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract DelegateFund is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address public assetsDestination;
  uint256 public assetsAmount;
  uint256 public timeOfExecution;
  
  // Enough time for devs to react for the withdrawal action
  uint256 public immutable delay = 2 days;
  
  // Events //

  event WithdrawalInitialisation(address to, uint256 amount, uint256 timeOfExecution);
  event WithdrawalSuccessful(address to, uint256 amount);

  constructor() {
  }
  
  // Functions //
  
  /** 
  * @dev Initialisation withdrawal process
  * @param _to The destination where funds will be withdrawn 
  * @param _amount The amount allowed to be withdrawn to the destination
  **/
  function withdrawInit(address _to, uint256 _amount) external onlyOwner {
    timeOfExecution = block.timestamp.add(delay);
    assetsDestination = _to;
    assetsAmount = _amount;

    emit WithdrawalInitialisation(_to, _amount, timeOfExecution);
  }
  
  /// @dev Withdrawal action for a specific asset found in the contract, emits event
  function withdraw(address _asset) external onlyOwner {
    require(block.timestamp >= timeOfExecution, "locked!");
    require(assetsDestination != address(0), "destination!");

    IERC20(_asset).safeTransfer(assetsDestination, assetsAmount);

    delete timeOfExecution;
    delete assetsDestination;
    delete assetsAmount;

    emit WithdrawalSuccessful(assetsDestination, assetsAmount);
  }
  
  /// @dev Cancels the process of withdrawal, assign default vault to variables
  function WithdrawalCancelation() external onlyOwner {
    delete timeOfExecution;
    delete assetsDestination;
    delete assetsAmount;
  }
}
