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
            amountWorking: uint256(0)
        });
    }

    /**
     * @dev Allows user to delegate to our protocol (first point of contact user:protocol)
     * @param _asset The asset which is delegated
     * @param _amount The amount delegated to us to manage
     * @notice we do not emit event as  `approveDelegation` emits -> BorrowAllowanceDelegated
     **/
    function delegateCreditLine(address _asset, uint256 _amount) public {
        (, , address variableDebtTokenAddress) =
            provider.getReserveTokensAddresses(_asset);

        IDebtToken(variableDebtTokenAddress).approveDelegation(
            address(this),
            _amount
        );

        DelegatorInfo storage delegator = delegators[msg.sender];

        if (_amount >= delegator.amountDelegated) {
            uint256 diffAllowance = _amount.sub(delegator.amountDelegated);

            totalDelegatedAmounts[_asset].add(diffAllowance);

            delegator.amountDelegated = _amount;

            //deployCapital(_asset, msg.sender);
        } else {
            uint256 diffAllowance = delegator.amountDelegated.sub(_amount);

            totalDelegatedAmounts[_asset].sub(diffAllowance);

            // Unwind - repay back debt, perhaps method called `unwind(diffAllowance, msg.sender)`
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
            uint256 amountToBorrow =
                delegator.amountDelegated.sub(delegator.amountDeployed);

            require(amountToBorrow > 0, "0!");

            lendingPool.borrow(_asset, amountToBorrow, 2, 0, msg.sender);

            delegator.amountDeployed = delegator.amountDeployed.add(
                amountToBorrow
            );

            IERC20(_asset).approve(strategyInfo.strategyAddress, amountToBorrow);

            IStrategy(strategyInfo.strategyAddress).deposit(amountToBorrow);

            strategyInfo.amountWorking = strategyInfo.amountWorking.add(
                amountToBorrow
            );
        }
    }
}
