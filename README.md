SatoshiDollar Stablecoin System on GoBob Network
================================================

**Disclaimer**: This project is a proof-of-concept developed for a hackathon and has not undergone a formal security audit. It should not be used in production without thorough testing and review.

Most of this work is inspired by the `MicroStable` project: https://www.youtube.com/watch?v=ShWTRmV1IFw

* * * * *

## Index

1. [Project Description](#project-description)
2. [Architecture Overview](#architecture-overview)
3. [Features](#features)
4. [How It Works](#how-it-works)
5. [Liquidation Mechanism](#liquidation-mechanism)
6. [Oracle Usage](#oracle-usage)
7. [Security Considerations](#security-considerations)
8. [Technical Details](#technical-details)
9. [Deployment and Setup](#deployment-and-setup)
10. [Usage Examples](#usage-examples)
11. [Future Improvements](#future-improvements)
12. [Tracks](#tracks)

Project Description
-------------------

SatoshiDollar is a decentralized stablecoin system built for the GoBob network, a hybrid Layer 2 (L2) blockchain that merges Bitcoin's security with Ethereum's flexibility. The system uses Wrapped Bitcoin (WBTC) as collateral, enabling users to mint a USD-pegged stablecoin called SatoshiDollar (satoshiUSD). By maintaining a minimum collateralization ratio and implementing a liquidation mechanism, SatoshiDollar ensures stability and security for users leveraging their Bitcoin holdings.

* * * * *

Architecture Overview
---------------------

The system is composed of two primary smart contracts:

-   **SatoshiDollar.sol**:

    -   An ERC20 token contract representing the stablecoin, SatoshiDollar (satoshiUSD).

    -   Only the Manager contract can mint or burn tokens, enforcing strict control over supply.

-   **Manager.sol** (named Microstable.sol in the code):

    -   The central contract managing collateral deposits, stablecoin minting and burning, and liquidation of undercollateralized positions.

    -   Integrates with an external oracle to fetch real-time BTC/USD prices for collateral valuation.

* * * * *

Features
--------

-   **Deposit Collateral**: Users can deposit WBTC to secure their positions.

-   **Mint Stablecoin**: Users can mint SatoshiDollar based on their WBTC collateral, provided they maintain a minimum collateralization ratio of 150%.

-   **Burn Stablecoin**: Users can burn SatoshiDollar to reduce their debt and improve their collateralization ratio.

-   **Withdraw Collateral**: Users can withdraw WBTC collateral if their position remains sufficiently collateralized.

-   **Liquidation**: Undercollateralized positions can be liquidated (fully or partially) by external actors, who earn a 5% bonus.

-   **Oracle Integration**: Uses an oracle to fetch BTC/USD prices, ensuring accurate collateral valuation.

* * * * *

How It Works
------------

1.  **Deposit Collateral**:

    -   Users call `deposit(uint256 amount)` to transfer WBTC to the Manager contract.

    -   The deposited amount is tracked in the user's balance.

3.  **Mint SatoshiDollar**:

    -   Users call `mint(uint256 amount)` to create `SatoshiDollar`.

    -   The system verifies that the collateralization ratio remains above 150% post-minting.

    -   If valid, `SatoshiDollar` is minted and sent to the user.

5.  **Burn SatoshiDollar**:

    -   Users call `burn(uint256 amount)` to destroy `SatoshiDollar`, reducing their debt.

    -   This can help maintain or improve their collateralization ratio.

7.  **Withdraw Collateral**:

    -   Users call `withdraw(uint256 amount)` to retrieve `WBTC`.

    -   The system ensures the collateralization ratio stays above 150% after withdrawal.

9.  **Liquidation**:

    -   If a user's collateralization ratio drops below 150% (e.g., due to a BTC price drop), their position can be liquidated.

    -   Liquidators can call `liquidate(address user)` for full liquidation or `liquidate(address user, uint256 debtAmount)` for partial liquidation.

    -   The liquidator burns the specified SatoshiDollar debt and receives the corresponding WBTC collateral plus a 5% bonus.

* * * * *

Liquidation Mechanism
---------------------

-   **Condition for Liquidation**:

    -   A position is undercollateralized if its collateralization ratio falls below 150% (represented as 1.5e18 in the contract).

    -   Checked via the isUnderwater(address user) function.

-   **Liquidation Process**:

    -   **Full Liquidation**: Burns all of the user's debt and transfers all their collateral to the liquidator.

    -   **Partial Liquidation**: The liquidator specifies an amount of debt to burn (debtAmount).

        -   The system calculates the proportional collateral to seize, adds a 5% bonus (LIQUIDATION_BONUS = 5e16), and transfers it to the liquidator.

        -   User balances are updated accordingly.

    -   An event PartialLiquidation is emitted for transparency.

* * * * *

Oracle Usage
------------

- Given that there is no Chainlink oracle on Bob right now we will be using our own oracle to get the price of BTC/USD.

-   The Manager contract uses an external oracle implementing the `IOracle` interface.

-   The `latestAnswer()` function returns the current BTC/USD price, used to calculate collateral value.

-   The contract owner can update the oracle address via updateOracle(address _oracle).

* * * * *

Security Considerations
-----------------------

-   **Minimum Collateralization Ratio**: Set at 150% to ensure overcollateralization and mitigate insolvency risks.

-   **Liquidation Bonus**: A 5% bonus incentivizes liquidators to maintain system stability by addressing undercollateralized positions.

-   **Oracle Dependency**: The system relies on a single oracle for price feeds. An inaccurate or compromised oracle could lead to misvalued collateral.

-   **Access Control**: Only the Manager can mint or burn SatoshiDollar, tying token supply to collateral management logic.

-   **Safe Math**: Uses Solady's SafeCastLib and FixedPointMathLib to prevent overflows and ensure precise calculations.

* * * * *

Technical Details
-----------------

-   **Libraries Used**:

    -   Solady ERC20: For the SatoshiDollar token implementation.

    -   Solady SafeCastLib: For safe type casting (e.g., uint256 to uint128).

    -   Solady FixedPointMathLib: For precise fixed-point arithmetic (e.g., mulDiv operations).

    -   Solady Ownable: For ownership and access control in the Manager contract.

-   **Oracle Interface**: Assumes a simple `IOracle` interface with `latestAnswer()` returning the BTC/USD price.

* * * * *

Deployment and Setup
--------------------

1.  **Deploy SatoshiDollar Contract**:

    -   Deploy `SatoshiDollar.sol` w.

2.  **Deploy Manager Contract**:

    -   Deploy `Manager.sol` (Microstable.sol) with:

        -   _wbtc: Address of the WBTC token contract.

        -   _satoshiDollar: Address of the deployed SatoshiDollar contract.

        -   _oracle: Address of a reliable BTC/USD price oracle.

3.  **Configure Oracle**:

    -   Ensure the oracle provides accurate BTC/USD price data in the expected format.

4. **Transfer ownership of SatoshiDollar**: Transfer Ownership of the SatoshiDollar contract to the Manager contract.
* * * * *

Usage Examples
--------------

Below are sample Solidity function calls to interact with the Manager contract:

-   **Deposit Collateral**:

```solidity
    manager.deposit(100000000); // Deposits 1 WBTC (assuming 8 decimals)`
```

-   **Mint SatoshiDollar**:

```solidity
    manager.mint(500000000000000000000); // Mints 500 satoshiUSD (18 decimals)`
```

-   **Burn SatoshiDollar**:

```solidity
    manager.burn(200000000000000000000); // Burns 200 satoshiUSD`
```

-   **Withdraw Collateral**:

```solidity
    manager.withdraw(50000000); // Withdraws 0.5 WBTC`

-   **Liquidate a Position (Partial)**:

```solidity
    manager.liquidate(userAddress, 100000000000000000000); // Liquidates 100 satoshiUSD of debt`
```

-   **Liquidate a Position (Full)**:

```solidity
    manager.liquidate(userAddress); // Fully liquidates the user's position`
```

* * * * *

Future Improvements
-------------------

-   **Multiple Collateral Types**: Support additional assets (e.g., ETH, other BTC derivatives) as collateral.

-   **Dynamic Collateral Ratios**: Adjust the minimum collateralization ratio based on market volatility.

-   **Advanced Liquidation**: Implement an auction system for more efficient collateral distribution.

-   **Oracle Redundancy**: Integrate multiple oracles or a decentralized oracle network (e.g., Chainlink) for greater reliability.

-   **User Interface**: Develop a front-end for easier interaction with the system.

* * * * *

## Tracks

### BOB Deployment addresses

- Oracle address: [0x26E0974891FA041fc4209Db62806E24CcC6D46A8](https://bob-sepolia.explorer.gobob.xyz/address/0x26E0974891FA041fc4209Db62806E24CcC6D46A8)
- SatoshiDollar address: [0x42Cbe837CB49EF7583214876DCB37224bc8824FF](https://bob-sepolia.explorer.gobob.xyz/address/0x42Cbe837CB49EF7583214876DCB37224bc8824FF)
- Manager address: [0x179A66cbA3FE8c44d63562AfD2524725c44BA372](https://bob-sepolia.explorer.gobob.xyz/address/0x179A66cbA3FE8c44d63562AfD2524725c44BA372)

### ROOTSTOCK Deployment addresses

- Oracle address: [0x8f9895491b38b6b9b21d18d21998ce55dc933988](https://explorer.testnet.rootstock.io/address/0x8f9895491b38b6b9b21d18d21998ce55dc933988)
- SatoshiDollar address: [0xbcdb8269e80fc67dc6f605f5be85895801ccd1ad](https://explorer.testnet.rootstock.io/address/0xbcdb8269e80fc67dc6f605f5be85895801ccd1ad)
- Manager address: []
