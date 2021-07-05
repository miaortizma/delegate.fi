// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interface/ICurvePool.sol";
import "./interface/IAaveGauge.sol";
import "./interface/ILendingPool.sol";
import "./interface/IAaveIncentivesController.sol";
import "./interface/IProtocolDataProvider.sol";
import "./interface/IAaveOracle.sol";
import "./interface/IUniswapV2Router02.sol";
import {IDividendRightsToken} from "./interface/IDividendRightsToken.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract StrategySimplify is Ownable, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ILendingPool lendingPool =
        ILendingPool(address(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf));
    IAaveIncentivesController aaveRewards =
        IAaveIncentivesController(0x357D51124f59836DeD84c8a1730D72B749d8BC23);
    IProtocolDataProvider provider =
        IProtocolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d);
    address public constant oracleAddress =
        0x0229F777B0fAb107F9591a41d5F02E4e98dB6f2d;
    address public variableDebtTokenAddr;

    ICurvePool public curvePool =
        ICurvePool(address(0x445FE580eF8d70FF569aB36e80c647af338db351));
    IAaveGauge public aaveGauge =
        IAaveGauge(address(0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c));
    IERC20 public lpCRV =
        IERC20(address(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171));
    int128 public curveId;

    ISuperToken public DAIx =
        ISuperToken(address(0x1305F6B6Df9Dc47159D12Eb7aC2804d4A33173c2));

    IUniswapV2Router02 sushiswapRouter =
        IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    address public constant weth =
        address(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    address public delegateFund;
    address public want;
    address public aWant;
    address public manager;
    address public drt;

    address public constant CRV =
        address(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
    address public constant WMATIC =
        address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    uint256 public constant MAX_FEE = 10000;
    uint256 public constant MAX_REVENUE = 2000;
    uint256 public REVENUE_FEE = 1500;
    uint256 public constant slippageMax = 35;
    uint256 public minSellThreshold = 0.5 ether;
    uint256 public lastRevenueDistribution = 0;
    uint256 public immutable REVENUE_DISTRIBUTION_FREQ = 2 days;
    uint256 public depositLimit;

    event UpdateDepositLimit(uint256 depositLimit, uint256 timestamp);
    event Deposited(uint256 amountDeposited, uint256 timestamp);
    event Harvest(
        uint256 curveHarvested,
        uint256 wmaticHarvested,
        uint256 curveProtocolFee,
        uint256 wmaticProtocolFee,
        uint256 wantConverted,
        uint256 indexed blockNumber
    );

    constructor(
        address[4] memory _initialConfig,
        uint256 _limit,
        int128 _curveId
    ) public {
        delegateFund = _initialConfig[0];
        want = _initialConfig[1];
        manager = _initialConfig[2];
        drt = _initialConfig[3];

        depositLimit = _limit;

        curveId = _curveId;

        (address aToken, , ) = provider.getReserveTokensAddresses(want);

        aWant = aToken;
        IERC20(want).safeApprove(address(lendingPool), type(uint256).max);
        IERC20(aWant).safeApprove(address(curvePool), type(uint256).max);
        IERC20(want).safeApprove(address(DAIx), type(uint256).max);
        lpCRV.safeApprove(address(aaveGauge), type(uint256).max);
    }

    /// --- View Functions ---

    /// @notice Amount of `want` via lp curve relationship
    function lpCurveToWant() public view returns (uint256) {
        uint256 lpRatio = curvePool.get_virtual_price();

        uint256 wantFromLp = balanceInGauge().mul(lpRatio).div(10**18);

        return wantFromLp;
    }

    /// @notice Amount of lp tokens deposited in Gauge
    function balanceInGauge() public view returns (uint256) {
        return aaveGauge.balanceOf(address(this));
    }

    /// @notice Idle want in strategy
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    /// @notice `want` deposit as collaterial in Aave
    function aaveDeposits() public view returns (uint256) {
        (uint256 totalCollateralETH, , , , , ) = lendingPool.getUserAccountData(
            address(this)
        );

        return totalCollateralETH.mul(10**18).div(aaveOracleRatio());
    }

    /// @notice `want` expressed in eth units
    function aaveOracleRatio() public view returns (uint256) {
        return IAaveOracle(oracleAddress).getAssetPrice(want);
    }

    /// @notice Provides insight of how many assets are under management expressed in `want`
    function totalAssets() public view returns (uint256) {
        return balanceOfWant().add(aaveDeposits()).add(lpCurveToWant());
    }

    /// --- Functions to pause certain methods (security) ---

    /// @notice It will freeze certain methods, to avoid exploits when needed
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Back to usual activity, once concerns are resolved
    function unpause() external onlyOwner {
        _unpause();
    }

    /// --- External Actions via `manager` ---

    /// @dev Deposit `want` asset into the strategy
    function deposit(uint256 _amount) external whenNotPaused {
        require(msg.sender == manager, "manager!");
        require(_amount > 0, "nothing!");

        uint256 amount = _amount;

        if (_amount == type(uint256).max) {
            amount = Math.min(
                IERC20(want).balanceOf(msg.sender),
                depositLimit.sub(totalAssets())
            );
        } else {
            require(
                totalAssets().add(_amount) <= depositLimit,
                ">depositLimit!"
            );
        }

        IERC20(want).safeTransferFrom(msg.sender, address(this), amount);

        lendingPool.deposit(want, amount, address(this), 0);

        _compoundingAction();

        emit Deposited(amount, block.timestamp);
    }

    /// @dev Withdraw `want` asset from the strategy into the DelegateCreditManager
    function withdraw(address _recipient, uint256 _amount)
        external
        whenNotPaused
    {
        require(msg.sender == manager, "manager!");
        require(_amount > 0, "nothing!");

        uint256 _wantBalanceIdle = IERC20(want).balanceOf(address(this));

        if (_wantBalanceIdle < _amount) {
            uint256 wantAmountRequired = _amount.sub(_wantBalanceIdle);

            _freeAavePositions(wantAmountRequired);
        }

        uint256 amountAfterSlippage = Math.min(_amount, balanceOfWant());

        IERC20(want).safeApprove(_recipient, amountAfterSlippage);

        IERC20(want).safeTransfer(_recipient, amountAfterSlippage);
    }

    /**
     * @dev [External] Free certain portion of positions owned by the strategy
     * @param _amount amount to free up
     **/
    function freeAavePositions(uint256 _amount) external onlyOwner {
        _freeAavePositions(_amount);
    }

    /**
     * @dev [Internal] Free certain portion of positions owned by the strategy
     * @param _amount amount to free up
     **/
    function _freeAavePositions(uint256 _amount) internal {
        if (balanceInGauge() > 0) {
            _withdrawCurvePool(_amount);
        }

        uint256 toWithdraw = Math.min(
            IERC20(aWant).balanceOf(address(this)),
            _amount
        );

        lendingPool.withdraw(want, toWithdraw, address(this));
    }

    /**
     * @dev [Internal] Withdraw Lp from Gauge and liq from Curve pool
     * @param _amount amount to removed
     **/
    function _withdrawCurvePool(uint256 _amount) internal {
        uint256 lpRatio = curvePool.get_virtual_price();

        uint256 lpFromWant = _amount.div(lpRatio).mul(10**18);

        uint256 lpToWithdraw = Math.min(lpFromWant, balanceInGauge());

        aaveGauge.withdraw(lpToWithdraw);

        uint256 _min_amount = lpToWithdraw.mul(MAX_FEE.sub(slippageMax)).div(
            MAX_FEE
        );

        curvePool.remove_liquidity_one_coin(lpToWithdraw, curveId, _min_amount);
    }

    // --- External Actions authorized only to `owner` ---

    /// @dev Harvest accum rewards from Gauge (CRV & WMATIC) and compound positions
    function harvest() external onlyOwner {
        (address aToken, , address variableDebt) = provider
        .getReserveTokensAddresses(want);

        address[] memory claimableAddresses = new address[](1);
        claimableAddresses[0] = aToken;

        aaveRewards.claimRewards(
            claimableAddresses,
            type(uint256).max,
            address(this)
        );

        aaveGauge.claim_rewards(address(this));

        uint256 curveBal = IERC20(CRV).balanceOf(address(this));
        uint256 wmaticBal = IERC20(WMATIC).balanceOf(address(this));

        (uint256 curveFee, uint256 wmaticFee) = protocolFee(
            curveBal,
            wmaticBal
        );

        curveBal = curveBal.sub(curveFee);
        wmaticBal = wmaticBal.sub(wmaticFee);

        if (wmaticBal > 0) {
            _recycleRewards(WMATIC, wmaticBal);
        }

        if (curveBal > 0) {
            _recycleRewards(CRV, curveBal);
        }

        uint256 amountToDeposit = IERC20(want).balanceOf(address(this));

        if (
            block.timestamp >=
            lastRevenueDistribution.add(REVENUE_DISTRIBUTION_FREQ)
        ) {
            amountToDeposit = _revenueToDistributor(amountToDeposit);

            lastRevenueDistribution = block.timestamp;

            lendingPool.deposit(want, amountToDeposit, address(this), 0);
        } else {
            lendingPool.deposit(want, amountToDeposit, address(this), 0);
        }

        _compoundingAction();

        emit Harvest(
            curveBal,
            wmaticBal,
            curveFee,
            wmaticFee,
            amountToDeposit,
            block.number
        );
    }

    /// @dev Sends 50% of revenue to DRT contract - test
    function _revenueToDistributor(uint256 _amount) internal returns (uint256) {
        uint256 revenue = _amount.mul(uint256(5000)).div(MAX_FEE);

        DAIx.upgrade(revenue);

        DAIx.approve(drt, revenue);

        IDividendRightsToken(drt).distribute(revenue);

        return IERC20(want).balanceOf(address(this));
    }

    /// @dev [External] Compound positions
    function compoundingAction() external onlyOwner {
        _compoundingAction();
    }

    /// @dev [Internal] Compound positions, keep in mind our HF in Aave
    function _compoundingAction() internal {
        uint256 aWantBalance = IERC20(aWant).balanceOf(address(this));

        uint256[3] memory amounts;

        if (curveId == 0) {
            amounts = [aWantBalance, 0, 0];
        } else if (curveId == 1) {
            amounts = [0, aWantBalance, 0];
        }

        uint256 min_mint_amount = aWantBalance
        .mul(MAX_FEE.sub(uint256(400)))
        .div(MAX_FEE);

        curvePool.add_liquidity(amounts, min_mint_amount);

        uint256 lpCrvBalance = lpCRV.balanceOf(address(this));

        aaveGauge.deposit(lpCrvBalance);
    }

    /**
     * @dev Recycle rewards for `want` via Sushiswap
     * @param _rewardAddress Reward address
     * @param _rewardAmount Amount of rewards to be recycled
     **/
    function _recycleRewards(address _rewardAddress, uint256 _rewardAmount)
        internal
    {
        if (_rewardAmount > minSellThreshold) {
            address[] memory path = new address[](3);
            path[0] = _rewardAddress;
            path[1] = weth;
            path[2] = address(want);

            IERC20(_rewardAddress).safeApprove(
                address(sushiswapRouter),
                _rewardAmount
            );

            sushiswapRouter.swapExactTokensForTokens(
                _rewardAmount,
                type(uint256).min,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    /**
     * @dev It will send revenue to our DelegateFund contract accordingly (depending on `REVENUE_FEE`)
     * @param curveHarvested  Total amount which has been harvested in harvest() of curve tokens
     * @param wmaticHarvested Total amount which has been harvested in harvest() of wmatic tokens
     **/
    function protocolFee(uint256 curveHarvested, uint256 wmaticHarvested)
        internal
        returns (uint256 curveFee, uint256 wmaticFee)
    {
        curveFee = curveHarvested.mul(REVENUE_FEE).div(MAX_FEE);

        IERC20(CRV).safeTransfer(delegateFund, curveFee);

        wmaticFee = wmaticHarvested.mul(REVENUE_FEE).div(MAX_FEE);

        IERC20(WMATIC).safeTransfer(delegateFund, wmaticFee);

        return (curveFee, wmaticFee);
    }

    /**
     * @dev Set fee
     * @param _revenueFee Set new revenue fee, max 15%
     **/
    function setRevenueFee(uint256 _revenueFee) external onlyOwner {
        require(_revenueFee <= MAX_REVENUE, ">MAX_REVENUE!");
        REVENUE_FEE = _revenueFee;
    }

    /**
     * @dev Set deposit limit
     * @param _limit Set new limit which can be deposited into the strategy
     **/
    function setDepositLimit(uint256 _limit) external onlyOwner {
        depositLimit = _limit;

        emit UpdateDepositLimit(depositLimit, block.timestamp);
    }
}
