pragma solidity >=0.6.0 <0.9.0;

interface IDebtToken {
  function approveDelegation(address delegatee, uint256 amount) external;
}