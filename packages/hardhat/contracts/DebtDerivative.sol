// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import "./interface/IRatingOracle.sol";
/*
contract DebtDerivative is Ownable, ERC1155 {
    using SafeMath for uint256;

    struct DebtDerivativeArgs {
        address borrower;
        address token;
        uint256 amount;
        uint256 loanDeadline;
    }

    struct DebtDerivativeInfo {
        address token;
        uint256 expecetedProfit;
        uint256 loanDeadline;
    }

    address public oracleAddress;

    // likely will be only stablecoins whitelisted (DAI, USDC) or whichever Supertokens may support smoothly...
    address[] public tokens;

    uint256 public DEADLINE_INTERVALS = 4000;
    // depending on trust and rate of the borrower maybe more days could be provided, maybe...
    uint256 public maxDeadline = 15 days;
    // it could be updated along the system when credit trustworthy relation is created between users and protocol...
    uint256 public maxBorrowable = 100000 ether;
    uint256 public nextDebtDerivativeId = 0;

    mapping(uint256 => DebtDerivativeInfo) public derivateInfo;
    mapping(address => bool) public whitelistedBorrower;
    mapping(address => bool) public activeLoan;

    event DerivativeDebtCreated(
        uint256 id,
        address borrower,
        address token,
        uint256 amount,
        uint256 loanDeadline
    );

    constructor(string memory _uri, address _oracleAddress) ERC1155(_uri) {
        oracleAddress = _oracleAddress;
    }

    /// @notice New URI for ERC1155 metadata
    /// @param _newUri The new URI
    function setURI(string memory _newUri) external onlyOwner {
        _setURI(_newUri);
    }

    /// @notice New borrower address to be whitelisted
    /// @param _borrower Potential borrower address
    function setWhitelistedBorrower(address _borrower) external onlyOwner {
        whitelistedBorrower[_borrower] = true;

        IRatingOracle(oracleAddress).initiliasedCreditInfo(_borrower);
    }

    /// @notice Set new borrowing cap
    /// @param _newBorrowingCap The new borrowing max amount
    function setWhitelistedBorrower(uint256 _newBorrowingCap)
        external
        onlyOwner
    {
        require(_newBorrowingCap > 0, "0!");

        maxBorrowable = _newBorrowingCap;
    }

    /// @notice It will query in our oracle which is the user rating given
    /// @param _borrower borrower who the system will check rating against
    function maxAllowedBorrowerDeadline(address _borrower)
        internal
        returns (uint256)
    {
        uint256 borrowerRating = IRatingOracle(oracleAddress).getRating(
            _borrower
        );

        uint256 deadline = 0;

        if (borrowerRating <= 25) {
            deadline = maxDeadline.mul(uint256(1000)).div(DEADLINE_INTERVALS);
        } else if (borrowerRating > 25 && borrowerRating <= 50) {
            deadline = maxDeadline.mul(uint256(2000)).div(DEADLINE_INTERVALS);
        } else if (borrowerRating > 50 && borrowerRating <= 75) {
            deadline = maxDeadline.mul(uint256(3000)).div(DEADLINE_INTERVALS);
        } else {
            deadline = maxDeadline;
        }

        require(deadline <= maxDeadline, ">maxDeadline");

        return deadline;
    }

    /// @dev It will generate a new debt derivative ID with a specific deadline based on _borrower credit history check
    /// @param _token Token which will be borrowed
    /// @param _amount Amount asked to be borrowed (thinking that probably should be capped also via oracle historical data!)
    /// @return The Debt Derivative ID
    function createDebtDerivative(address _token) external returns (uint256) {
        // likely it will be either voted via governance or after devs clasify the borrower as "safe", bias?
        require(whitelistedBorrower[msg.sender], "notWhitelisted!");

        uint256 borrowableAmount = IRatingOracle(oracleAddress)
        .getMaxLoanAmount(msg.sender);

        require(borrowableAmount <= maxBorrowable, ">maxBorrowable");

        uint256 _loanDeadline = maxAllowedBorrowerDeadline(msg.sender);

        DebtDerivativeArgs memory debtDerivativeArgs = DebtDerivativeArgs({
            borrower: msg.sender,
            token: _token,
            amount: borrowableAmount,
            loanDeadline: block.timestamp + _loanDeadline
        });

        return _generateDebtDerivative(debtDerivativeArgs);
    }

    /// @notice Generates the new erc1155 debt derivative representation
    /// @param _args Debt derivative details to generate
    /// @return The Debt Derivative ID
    function _generateDebtDerivative(DebtDerivativeArgs memory _args)
        internal
        returns (uint256)
    {
        require(_args.amount > 0, "<0!");
        require(!activeLoan[_args.borrower], "active!");

        // here we should transfer funds from our creditManager to borrower based on _args...

        _mint(_args.borrower, nextDebtDerivativeId, _args.amount, "");

        activeLoan[_args.borrower] = true;

        nextDebtDerivativeId = nextDebtDerivativeId.add(1);

        emit DerivativeDebtCreated(
            _id,
            _args.borrower,
            _args.token,
            _args.amount,
            _args.loanDeadline
        );

        return _id;
    }
}
*/
