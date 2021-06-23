pragma solidity >=0.6.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./interface/ICurvePool.sol";
import "./interface/IAaveGauge.sol";

contract Strategy is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// Curve.fi related contracts
    ICurvePool public curvePool =
        ICurvePool(address(0x445FE580eF8d70FF569aB36e80c647af338db351));
    IAaveGauge public aaveGauge =
        IAaveGauge(address(0xe381C25de995d62b453aF8B931aAc84fcCaa7A62));
    IERC20 public lpCRV =
        IERC20(address(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171));

    int128 public curveId;

    address public delegateFund;
    address public want; // it could DAI, USDC or USDT (which?)
    address public manager;

    /// Tokens involved in the strategy
    address public constant CRV =
        address(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
    address public constant WMATIC =
        address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

    uint256 public constant MAX_FEE = 10000;
    uint256 public REVENUE_FEE = 1000;
    uint256 public depositLimit;

    event UpdateDepositLimit(uint256 depositLimit, uint256 timestamp);
    event Deposited(uint256 amountDeposited, uint256 timestamp);
    event RepayDebt(uint256 repaidDebt, uint256 existingAaveDebt);
    event Harvest(
        uint256 curveHarvested,
        uint256 wmaticHarvested,
        uint256 curveProtocolFee,
        uint256 wmaticProtocolFee,
        uint256 indexed blockNumber
    );

    constructor(
        address[3] memory _initialConfig,
        uint256 _limit,
        int128 _curveId
    ) public {
        delegateFund = _initialConfig[0];
        want = _initialConfig[1];
        manager = _initialConfig[2];

        depositLimit = _limit;

        curveId = _curveId;
    }

    /// --- View Functions ---

    /// @notice Amount of `want` via lp curve relationship
    function lpCurveToWant() public view returns (uint256) {
        uint256 lpRatio = curvePool.get_virtual_price().div(10**18);

        uint256 wantFromLp = lpRatio.mul(balanceInGauge()).div(10**18);

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

    /// @notice Provides insight of how many assets are under management expressed in `want`
    function totalAssets() public view returns (uint256) {
        return balanceOfWant().add(0);
    }

    /// @dev Deposit `want` asset into the strategy
    function deposit(uint256 _amount) external {
        require(msg.sender == manager, "manager!");
        require(_amount > 0, "nothing!");

        uint256 amount = _amount;

        if (_amount == uint256(-1)) {
            amount = Math.min(
                IERC20(want).balanceOf(msg.sender),
                depositLimit.sub(totalAssets())
            );
        } else {
            require(totalAssets().add(_amount) <= depositLimit, "overLimit!");
        }

        IERC20(want).safeTransferFrom(msg.sender, address(this), amount);

        emit Deposited(amount, block.timestamp);
    }

    /// @dev Withdraw `want` asset from the strategy into the DelegateCreditManager
    function withdraw(address _recipient, uint256 _amount) external {
        require(msg.sender == manager, "manager!");
        require(_amount > 0, "nothing!");

        uint256 _wantBalanceIdle = IERC20(want).balanceOf(address(this));

        if (_wantBalanceIdle >= _amount) {
            IERC20(want).approve(_recipient, _amount);

            IERC20(want).safeTransferFrom(address(this), _recipient, _amount);
        } else {
            // in this case we will need to withdraw from where the strategy is deploying the assets
        }
    }

    /// @dev Harvest accum rewards from Gauge (CRV & WMATIC)
    function harvest() external onlyOwner {
        aaveGauge.claim_rewards(address(this));

        uint256 curveBal = IERC20(CRV).balanceOf(address(this));
        uint256 wmaticBal = IERC20(WMATIC).balanceOf(address(this));

        (uint256 curveFee, uint256 wmaticFee) = protocolFee(
            curveBal,
            wmaticBal
        );

        curveBal = curveBal.sub(curveFee);
        wmaticBal = wmaticBal.sub(wmaticFee);

        if (wmaticBal > 0 || curveBal > 0) {
            // 1. It would be sold in the secondary market for more `want`
        }

        emit Harvest(curveBal, wmaticBal, curveFee, wmaticFee, block.number);
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
        require(_revenueFee <= 1500, "too_high!");
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
