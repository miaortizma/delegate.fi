// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestErc20 is ERC20 {
    constructor() ERC20("TestToken", "TESTING") public {
    }

    function mint(address _account, uint256 _amount) public {
        _mint(_account, _amount);
    }
}