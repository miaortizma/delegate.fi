//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interface/ILendingPool.sol";
import "./interface/IDebtToken.sol";
import "./interface/IProtocolDataProvider.sol";
import "./interface/IStrategy.sol";
import "./interface/IAaveOracle.sol";
import "./interface/IDividendRightsToken.sol";

contract DelegateCreditManager is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct DelegatorInfo {
        uint256 amountDelegated;
        uint256 amountDeployed;
    }

    struct StrategyInfo {
        address strategyAddress;
        uint256 amountWorking;
    }

    ILendingPool lendingPool;
    IProtocolDataProvider provider;
    address public constant oracleAddress =
        0x0229F777B0fAb107F9591a41d5F02E4e98dB6f2d;

    address public drt;

    uint256 public constant MAX_REF = 10000;
    uint256 public constant SAFE_REF = 4500;

    mapping(address => mapping(address => DelegatorInfo)) public delegators;
    mapping(address => StrategyInfo) public strategies; // perhaps, for simplicity one strategy per asset
    mapping(address => uint256) public totalDelegatedAmounts;

    event DeployedDelegatedCapital(
        address delegator,
        uint256 amountDeployed,
        address strategy,
        uint256 timestamp
    );
    event FreeDelegatedCapital(
        address delegator,
        uint256 amountRemoved,
        address strategy,
        uint256 timestamp
    );

    constructor(
        ILendingPool _lendingPool,
        IProtocolDataProvider _provider,
        address _drt
    ) public {
        lendingPool = _lendingPool;
        provider = _provider;
        drt = _drt;
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
     * @dev Allows user to first deposit in Aave and then delegate (point of contact user:protocol)
     * @param _assetDeposit The asset which is deposited in Aave
     * @param _assetStrategy The asset used in the strategy
     * @param _amount The amount deposited in Aave of _assetDeposit type
     **/
    function depositAaveAndDelegate(
        address _assetDeposit,
        address _assetStrategy,
        uint256 _amount
    ) external {
        IERC20(_assetDeposit).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        lendingPool.deposit(_assetDeposit, _amount, msg.sender, 0);

        (, , uint256 availableBorrowsETH, , , ) = lendingPool
        .getUserAccountData(msg.sender);

        uint256 ratioOracle = IAaveOracle(oracleAddress).getAssetPrice(
            _assetStrategy
        );

        uint256 safeDelegableAmount = availableBorrowsETH
        .mul(10**18)
        .mul(SAFE_REF)
        .div(MAX_REF)
        .div(ratioOracle);

        _delegateCreditLine(_assetStrategy, safeDelegableAmount);
    }

    /// @dev Allows user to delegate to our protocol (point of contact user:protocol)
    function delegateCreditLine(address _asset, uint256 _amount) external {
        _delegateCreditLine(_asset, _amount);
    }

    /**
     * @param _asset The asset which is delegated
     * @param _amount The amount delegated to us to manage
     **/
    function _delegateCreditLine(address _asset, uint256 _amount) internal {
        (, , address variableDebtTokenAddress) = provider
        .getReserveTokensAddresses(_asset);

        uint256 borrowableAllowance = IDebtToken(variableDebtTokenAddress)
        .borrowAllowance(msg.sender, address(this));

        DelegatorInfo storage delegator = delegators[msg.sender][_asset];

        if (borrowableAllowance > 0) {
            totalDelegatedAmounts[_asset] = totalDelegatedAmounts[_asset].add(
                borrowableAllowance
            );

            delegator.amountDelegated = delegator.amountDelegated.add(
                borrowableAllowance
            );

            deployCapital(_asset, msg.sender);
        }
    }

    /// @dev Allows user to remove from protocol delegated funds (point of contact user:protocol)
    function freeDelegatedCapital(address _asset, uint256 _amount) external {
        unwindCapital(_asset, msg.sender, _amount);
    }

    /**
     * @param _asset The asset which is going to be remove from strategy
     * @param _delegator Delegator address, use to update mapping
     * @param _amount Amount to unwind from our system and repay Aaave
     **/
    function unwindCapital(
        address _asset,
        address _delegator,
        uint256 _amount
    ) internal {
        DelegatorInfo storage delegator = delegators[_delegator][_asset];

        require(_amount <= delegator.amountDelegated, ">amountDelegated");

        StrategyInfo storage strategyInfo = strategies[_asset];

        require(strategyInfo.strategyAddress != address(0), "notSetStrategy!");

        require(delegator.amountDeployed > 0, "noDeployedCapital!");

        delegator.amountDelegated = delegator.amountDelegated.sub(_amount);

        delegator.amountDeployed = delegator.amountDeployed.sub(_amount);

        totalDelegatedAmounts[_asset] = totalDelegatedAmounts[_asset].add(
            _amount
        );

        IStrategy(strategyInfo.strategyAddress).withdraw(
            address(this),
            _amount
        );

        uint256 repayableAmount = Math.min(
            _amount,
            IERC20(_asset).balanceOf(address(this))
        );

        lendingPool.repay(_asset, repayableAmount, 2, _delegator);

        IDividendRightsToken(drt).burn(_delegator, repayableAmount);

        emit FreeDelegatedCapital(
            _delegator,
            repayableAmount,
            strategyInfo.strategyAddress,
            block.timestamp
        );
    }

    /**
     * @dev Deploys the new delegated inmediatly into the strategy
     * @param _asset The asset which is going to be deployed
     * @param _delegator Delegator address, use to update mapping
     **/
    function deployCapital(address _asset, address _delegator) internal {
        StrategyInfo storage strategyInfo = strategies[_asset];

        require(strategyInfo.strategyAddress != address(0), "notSetStrategy!");

        DelegatorInfo storage delegator = delegators[_delegator][_asset];

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
            
            IDividendRightsToken(drt).issue(_delegator, amountToBorrow);

            emit DeployedDelegatedCapital(
                _delegator,
                amountToBorrow,
                strategyInfo.strategyAddress,
                block.timestamp
            );
        }
    }
}
