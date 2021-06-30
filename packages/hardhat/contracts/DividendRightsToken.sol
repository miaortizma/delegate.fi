// SPDX-License-Identifier: MIT
pragma solidity >=0.7.3 <0.9.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import {ISuperfluid, ISuperToken, SuperAppBase, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import {IInstantDistributionAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * The dividends rights token show cases two use cases
 * 1. Use Instant distribution agreement to distribute tokens to token holders.
 * 2. Use SuperApp framework to update `isSubscribing` when new subscription is approved by token holder.
 */
contract DividendRightsToken is Ownable, ERC20, SuperAppBase {
    uint32 public constant INDEX_ID = 0;

    ISuperToken private _cashToken;
    ISuperfluid private _host;
    IInstantDistributionAgreementV1 private _ida;

    constructor(
        string memory name,
        string memory symbol,
        ISuperToken cashToken,
        ISuperfluid host,
        IInstantDistributionAgreementV1 ida
    ) ERC20(name, symbol) {
        _cashToken = cashToken;
        _host = host;
        _ida = ida;

        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.createIndex.selector,
                _cashToken,
                INDEX_ID,
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );

        transferOwnership(msg.sender);
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    /// @dev Issue new `amount` of giths to `beneficiary`
    function issue(address beneficiary, uint256 amount) external onlyOwner {
        // then adjust beneficiary subscription units
        uint256 currentAmount = balanceOf(beneficiary);

        // first try to do ERC20 mint
        ERC20._mint(beneficiary, amount);

        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.updateSubscription.selector,
                _cashToken,
                INDEX_ID,
                beneficiary,
                uint128(currentAmount) + uint128(amount),
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
    }

    /// @dev Burn `amount` DRT and update subscription to IDA of `account`
    function burn(address account, uint256 amount) external onlyOwner {
        uint256 currentAmount = balanceOf(account);

        ERC20._burn(account, amount);

        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.updateSubscription.selector,
                _cashToken,
                INDEX_ID,
                account,
                uint128(currentAmount) - uint128(amount),
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
    }

    /// @dev needs testing
    function approveSubscription() public {
        require(false);
        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.approveSubscription.selector,
                _cashToken,
                INDEX_ID,
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
    }

    /// @dev Distribute `amount` of cash among all token holders
    function distribute(uint256 cashAmount) external onlyOwner {
        (uint256 actualCashAmount, ) = _ida.calculateDistribution(
            _cashToken,
            address(this),
            INDEX_ID,
            cashAmount
        );
        console.log("INDEX_ID", INDEX_ID);
        console.log("ActualCashAmount", actualCashAmount);
        console.log("Balance Of Owner", _cashToken.balanceOf(owner()));
        _cashToken.transferFrom(owner(), address(this), actualCashAmount);

        console.log("Distribute");
        console.log("BalanceOf:", _cashToken.balanceOf(address(this)));

        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.distribute.selector,
                _cashToken,
                INDEX_ID,
                actualCashAmount,
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );

        console.log("After Distribute");
        console.log("BalanceOf:", _cashToken.balanceOf(address(this)));
        console.log("Balance Of Owner", _cashToken.balanceOf(owner()));
    }

    /// @dev ERC20._transfer override
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        uint128 senderUnits = uint128(ERC20.balanceOf(sender));
        uint128 recipientUnits = uint128(ERC20.balanceOf(recipient));
        // first try to do ERC20 transfer
        ERC20._transfer(sender, recipient, amount);

        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.updateSubscription.selector,
                _cashToken,
                INDEX_ID,
                sender,
                senderUnits - uint128(amount),
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );

        _host.callAgreement(
            _ida,
            abi.encodeWithSelector(
                _ida.updateSubscription.selector,
                _cashToken,
                INDEX_ID,
                recipient,
                recipientUnits + uint128(amount),
                new bytes(0) // placeholder ctx
            ),
            new bytes(0) // user data
        );
    }
}
