// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RatingOracle is Ownable {
    using SafeMath for uint256;

    struct CreditDetails {
        uint256 rating;
        uint256 maxLoanAmount;
        uint256 profits;
        bool defaulted;
        bool initialised;
    }

    address public director;

    uint256 public LOAN_INCREMENT = 3000 ether;
    uint256 public LOAN_DECREMENT = 5000 ether;
    uint256 public constant INITIAL_ALLOWANCE = 10000 ether;

    /// @dev Stores the last credit details for a specific address
    mapping(address => CreditDetails) public creditHistory;

    /// @notice Set new director
    /// @param _director Director address with rights to initiliased/update credit details
    function setDirector(address _director) external onlyOwner {
        director = _director;
    }

    /// @notice Provides borrower rating status
    /// @param _borrower Borrower address info requested
    function getRating(address _borrower) external view returns (uint256) {
        return creditHistory[_borrower].rating;
    }

    /// @notice Provides max amount that borrow can grab
    /// @param _borrower Borrower address info requested
    function getMaxLoanAmount(address _borrower)
        external
        view
        returns (uint256)
    {
        return creditHistory[_borrower].maxLoanAmount;
    }

    /**
     * @notice Initiliased the whitelisted borrower state
     * @param _borrower address to initiliased
     */
    function initiliasedCreditInfo(address _borrower) external {
        require(msg.sender == director, "director!");

        creditHistory[_borrower] = CreditDetails({
            rating: 50,
            maxLoanAmount: INITIAL_ALLOWANCE,
            profits: 0,
            defaulted: false,
            initialised: true
        });
    }

    /**
     * @notice Updates borrower credit history
     * @param _borrower address to update its details
     * @param _ratingChange represents the change which will be execute in this update up || down
     * @param _lastProfit Amount that borrower has generated
     * @param _defaulted  Specifies if this user defaulted in its last uncollateral
     */
    function updateCreditInfo(
        address _borrower,
        uint256 _ratingChange,
        uint256 _lastProfit,
        bool _defaulted
    ) external {
        require(msg.sender == director, "director!");

        CreditDetails storage details = creditHistory[_borrower];

        require(details.initialised, "notInitiliased!");

        if (_defaulted) {
            details.rating = details.rating.sub(_ratingChange);
            details.maxLoanAmount = details.maxLoanAmount.sub(LOAN_DECREMENT);
        } else {
            details.rating = details.rating.add(_ratingChange);
            details.maxLoanAmount = details.maxLoanAmount.add(LOAN_INCREMENT);
        }

        details.defaulted = _defaulted;
        details.profits = details.profits.add(_lastProfit);
    }
}
