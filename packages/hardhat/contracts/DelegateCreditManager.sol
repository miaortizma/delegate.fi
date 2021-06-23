//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
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

    struct StrategyInfo {
        address strategyAddress;
        uint256 amountWorking;
    }

    ILendingPool lendingPool;
    IProtocolDataProvider provider;

    mapping(address => DelegatorInfo) public delegators;
    mapping(address => StrategyInfo) public strategies; // perhaps, for simplicity one strategy per asset
    mapping(address => uint256) public totalDelegatedAmounts;

    constructor(ILendingPool _lendingPool, IProtocolDataProvider _provider)
        public
    {
        lendingPool = _lendingPool;
        provider = _provider;
    }

    /**
     * @dev Sets the new strategy where funds will be deployed for a specific asset type
     * @param _asset Asset which the strategy will use for generating $
     * @param _strategy The new strategy address
     **/
    function setNewStrategy(address _asset, address _strategy)
        external
        onlyOwner
    {
        strategies[_asset] = StrategyInfo({
            strategyAddress: _strategy,
            amountWorking: type(uint256).min
        });

        IERC20(_asset).approve(_strategy, type(uint256).max);
        IERC20(_asset).approve(address(lendingPool), type(uint256).max);
    }

    /**
     * @dev Allows user to delegate to our protocol (first point of contact user:protocol)
     * @param _asset The asset which is delegated
     * @param _amount The amount delegated to us to manage
     * @notice we do not emit event as  `approveDelegation` emits -> BorrowAllowanceDelegated
     **/
    function delegateCreditLine(address _asset, uint256 _amount) public {
        (, , address variableDebtTokenAddress) = provider
        .getReserveTokensAddresses(_asset);

        IDebtToken(variableDebtTokenAddress).approveDelegation(
            address(this),
            _amount
        );

        DelegatorInfo storage delegator = delegators[msg.sender];

        if (_amount >= delegator.amountDelegated) {
            uint256 diffAllowance = _amount.sub(delegator.amountDelegated);

            totalDelegatedAmounts[_asset] = totalDelegatedAmounts[_asset].add(
                diffAllowance
            );

            delegator.amountDelegated = _amount;

            deployCapital(_asset, msg.sender);

            // we should issue aka mint here some shares to track the revenue we should provide to each delegator
        } else {
            uint256 diffAllowance = delegator.amountDelegated.sub(_amount);

            totalDelegatedAmounts[_asset] = totalDelegatedAmounts[_asset].sub(
                diffAllowance
            );

            delegator.amountDelegated = _amount;

            unwindCapital(_asset, msg.sender);

            // we should burn here the shares given to the users accordingly
        }
    }

    /**
     * @dev Unwind the desired amount from the strategy after decreasing the allowance, repay allowance debt
     * @param _asset The asset which is going to be remove from strategy
     * @param _delegator Delegator address, use to update mapping
     **/
    function unwindCapital(address _asset, address _delegator) internal {
        StrategyInfo storage strategyInfo = strategies[_asset];

        require(strategyInfo.strategyAddress != address(0), "notSet!");

        DelegatorInfo storage delegator = delegators[_delegator];

        require(delegator.amountDeployed > 0, "noDeployed!");

        if (delegator.amountDelegated < delegator.amountDeployed) {
            uint256 amountToUnwind = delegator.amountDeployed.sub(
                delegator.amountDelegated
            );

            require(amountToUnwind > 0, "0!");

            IStrategy(strategyInfo.strategyAddress).withdraw(
                address(this),
                amountToUnwind
            );

            lendingPool.repay(_asset, amountToUnwind, 2, _delegator);

            strategyInfo.amountWorking = strategyInfo.amountWorking.sub(
                amountToUnwind
            );
        }
    }

    /**
     * @dev Deploys the new delegated inmediatly into the strategy
     * @param _asset The asset which is going to be deployed
     * @param _delegator Delegator address, use to update mapping
     **/
    function deployCapital(address _asset, address _delegator) internal {
        StrategyInfo storage strategyInfo = strategies[_asset];

        require(strategyInfo.strategyAddress != address(0), "notSet!");

        DelegatorInfo storage delegator = delegators[_delegator];

        if (delegator.amountDelegated >= delegator.amountDeployed) {
            uint256 amountToBorrow = delegator.amountDelegated.sub(
                delegator.amountDeployed
            );

            require(amountToBorrow > 0, "0!");

            lendingPool.borrow(_asset, amountToBorrow, 2, 0, _delegator);

            delegator.amountDeployed = delegator.amountDeployed.add(
                amountToBorrow
            );

            IStrategy(strategyInfo.strategyAddress).deposit(amountToBorrow);

            strategyInfo.amountWorking = strategyInfo.amountWorking.add(
                amountToBorrow
            );
        }
    }
}
