// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SatoshiDollar} from "./SatoshiDollar.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {Ownable} from "solady/auth/Ownable.sol";

interface IOracle {
    function latestAnswer() external view returns (uint256);
}

contract Manager is Ownable {
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;

    struct UserBalance {
        uint128 deposited;
        uint128 minted;
    }

    error ErrCollateralRatioTooLow();

    // Events
    event PartialLiquidation(
        address indexed user, address indexed liquidator, uint256 debtLiquidated, uint256 collateralSeized
    );

    uint256 public constant MIN_COLLAT_RATIO = 1.5e18;
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5% bonus for liquidators

    ERC20 public immutable wbtc;
    SatoshiDollar public immutable satoshiDollar;
    IOracle public oracle;

    mapping(address => UserBalance) public userBalances;

    constructor(address _wbtc, address _satoshiDollar, address _oracle) {
        wbtc = ERC20(_wbtc);
        satoshiDollar = SatoshiDollar(_satoshiDollar);
        oracle = IOracle(_oracle);
    }

    function updateOracle(address _oracle) public onlyOwner {
        oracle = IOracle(_oracle);
    }

    function deposit(uint256 amount) public {
        wbtc.transferFrom(msg.sender, address(this), amount);
        userBalances[msg.sender].deposited += amount.toUint128();
    }

    function burn(uint256 amount) public {
        userBalances[msg.sender].minted -= amount.toUint128();
        satoshiDollar.burn(msg.sender, amount);
    }

    function mint(uint256 amount) public {
        userBalances[msg.sender].minted += amount.toUint128();
        if (collatRatio(msg.sender) < MIN_COLLAT_RATIO) {
            revert ErrCollateralRatioTooLow();
        }
        satoshiDollar.mint(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        userBalances[msg.sender].deposited -= amount.toUint128();
        require(collatRatio(msg.sender) >= MIN_COLLAT_RATIO);
        wbtc.transfer(msg.sender, amount);
    }

    function liquidate(address user) external {
        require(isUnderwater(user), "Position is healthy");
        satoshiDollar.burn(msg.sender, userBalances[user].minted);
        wbtc.transfer(msg.sender, userBalances[user].deposited);
        delete userBalances[user];
    }

    function liquidate(address user, uint256 debtAmount) external {
        require(isUnderwater(user), "Position is healthy");

        UserBalance storage userBalance = userBalances[user];

        require(debtAmount <= uint256(userBalance.minted), "Cannot liquidate more than debt");
        require(debtAmount > 0, "Must liquidate non-zero amount");

        // Calculate the proportion of collateral to seize
        uint256 totalDebt = userBalance.minted;
        uint256 totalCollateral = userBalance.deposited;

        // Calculate collateral to seize including bonus
        uint256 baseCollateral = totalCollateral.mulDiv(debtAmount, totalDebt);
        uint256 bonusCollateral = baseCollateral.mulDiv(LIQUIDATION_BONUS, 1 ether);
        uint256 collateralToSeize = baseCollateral + bonusCollateral;

        // Ensure we don't seize more than available
        require(collateralToSeize <= totalCollateral, "Not enough collateral");

        // Update state
        userBalance.minted -= debtAmount.toUint128();
        userBalance.deposited -= collateralToSeize.toUint128();

        // Transfer assets
        satoshiDollar.burn(msg.sender, debtAmount);
        wbtc.transfer(msg.sender, collateralToSeize);

        // Emit event for tracking
        emit PartialLiquidation(user, msg.sender, debtAmount, collateralToSeize);
    }

    function collatRatio(address user) public view returns (uint256) {
        UserBalance storage _userBalance = userBalances[user];
        if (_userBalance.minted == 0) return type(uint256).max;
        uint256 totalValue = uint256(_userBalance.deposited) * oracle.latestAnswer(); // * 1e10;
        return totalValue.mulDiv(1e10, uint256(_userBalance.minted));
    }

    function isUnderwater(address user) public view returns (bool) {
        return collatRatio(user) < MIN_COLLAT_RATIO;
    }

    function address2deposit(address u) public view returns (uint256) {
        return uint256(userBalances[u].deposited);
    }

    function address2minted(address u) public view returns (uint256) {
        return uint256(userBalances[u].minted);
    }
}
