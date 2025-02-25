// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solady/tokens/ERC20.sol";

contract SatoshiDollar is ERC20 {
    address public immutable manager;

    function name() public view override returns (string memory) {
        return "SatoshiDollar";
    }

    function symbol() public view override returns (string memory) {
        return "satoshiUSD";
    }

    constructor(address _manager) {
        manager = _manager;
    }

    modifier onlyManager() {
        require(manager == msg.sender);
        _;
    }

    function mint(address to, uint256 amount) external onlyManager {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyManager {
        _burn(from, amount);
    }
}
