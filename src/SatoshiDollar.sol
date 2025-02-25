// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solady/tokens/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

contract SatoshiDollar is ERC20, Ownable {
    address public immutable manager;

    constructor() {
        _setOwner(msg.sender);
    }

    function name() public view override returns (string memory) {
        return "SatoshiDollar";
    }

    function symbol() public view override returns (string memory) {
        return "satoshiUSD";
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
