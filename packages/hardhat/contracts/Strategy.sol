pragma solidity >=0.6.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./interface/ICurvePool.sol";

contract Strategy is Ownable {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  ICurvePool public curvePool = ICurvePool(address(0x445FE580eF8d70FF569aB36e80c647af338db351));
  IERC20 public lpCRV = IERC20(address(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171));

  int128 public curveId;

  address public delegateFund;
  address public want; // it could DAI, USDC or USDT (which?)

  uint256 public constant MAX_FEE = 10000;
  uint256 public REVENUE_FEE = 1000;
  uint256 public depositLimit;
  
  event UpdateDepositLimit(uint256 depositLimit, uint256 timestamp);
  event Deposited(uint256 amountDeposited, uint256 timestamp);
  event RepayDebt(uint256 repaidDebt, uint256 existingAaveDebt);

  constructor(address[2] memory _initialConfig, uint256 _limit, int128 _curveId) public {
    delegateFund = _initialConfig[0];
    want = _initialConfig[1];

    depositLimit = _limit;

    curveId = _curveId;
  }
  
  /// --- View Functions ---

  function lpCurveToWant() public view returns (uint256) {
    uint256 lpRatio = curvePool.get_virtual_price().div(10**18);

    uint256 wantFromLp = lpRatio.mul(lpCRV.balanceOf(address(this))).div(10**18);

    return wantFromLp;
  }

  /// @notice Idle want in strat
  function balanceOfWant() public view returns (uint256) {
    return IERC20(want).balanceOf(address(this));
  }

  function totalAssets() internal view returns (uint256) {
    return balanceOfWant().add(0);
  }

  function deposit(uint256 _amount) external onlyOwner {
    require(_amount > 0, "nothing!");

    uint256 amount = _amount;

    if (_amount == uint256(-1)) {
      amount = 
        Math.min(
          IERC20(want).balanceOf(msg.sender), 
          depositLimit.sub(totalAssets())
        );
    } else {
      require(totalAssets().add(_amount) <= depositLimit, "overLimit!");
    }

    IERC20(want).safeTransferFrom(msg.sender, address(this), amount);

    emit Deposited(amount, block.timestamp);
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
