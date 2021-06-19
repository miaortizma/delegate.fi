pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestErc20 is ERC20 {
    constructor(uint8 _decimals) ERC20("TestToken", "TESTING") {
        _setupDecimals(_decimals);
    }

    function mint(address _account, uint256 _amount) public {
        _mint(_account, _amount);
    }
}