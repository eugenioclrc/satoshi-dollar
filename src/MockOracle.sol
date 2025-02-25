// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "solady/auth/Ownable.sol";

interface IOracle {
    function latestAnswer() external view returns (uint256);
}

contract MockOracle is Ownable {
    uint256 public price;

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function latestAnswer() external view returns (uint256) {
        return price;
    }
}