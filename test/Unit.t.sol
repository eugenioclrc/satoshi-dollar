// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Manager, SatoshiDollar, IOracle} from "../src/MicroStable.sol";
import {WETH} from "solady/tokens/WETH.sol";

contract MicroStableTest is Test {
    Manager public manager;
    SatoshiDollar public satoshiDollar;
    WETH public weth;
    address public oracle = makeAddr("oracle");

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant INITIAL_ETH_PRICE = 2000e8; // $2000 per ETH
    uint256 constant INITIAL_DEPOSIT = 10 ether;
    uint256 constant INITIAL_MINT = 6666_666666666666666666; // $10000 worth of satoshiDollar

    event PartialLiquidation(
        address indexed user, address indexed liquidator, uint256 debtLiquidated, uint256 collateralSeized
    );

    function setUp() public {
        weth = new WETH();
        // Predict manager's address

        satoshiDollar = new SatoshiDollar();
        manager = new Manager(address(weth), address(satoshiDollar), oracle);
        satoshiDollar.transferOwnership(address(manager));

        // setup price is 2000$ per ETHER
        vm.mockCall(oracle, abi.encodeWithSelector(IOracle.latestAnswer.selector), abi.encode(2000e8));

        // Setup test actors and pre approve WETH
        vm.prank(alice);
        weth.approve(address(manager), type(uint256).max);
        deal(address(weth), alice, INITIAL_DEPOSIT);

        vm.prank(bob);
        weth.approve(address(manager), type(uint256).max);
    }

    // Basic functionality tests
    function test_deposit(uint256 amount) public {
        // nobody will ever deposit more than 2^128 WETH in this contract
        amount = bound(amount, 0, type(uint128).max);
        deal(address(weth), bob, amount);
        vm.startPrank(bob);
        manager.deposit(amount);
        assertEq(manager.address2deposit(bob), amount);
        assertEq(weth.balanceOf(address(manager)), amount);
        vm.stopPrank();
    }

    function test_mint() public {
        vm.startPrank(alice);
        manager.deposit(INITIAL_DEPOSIT);

        assertEq(manager.collatRatio(address(alice)), type(uint256).max);

        // user deposit INITIAL_DEPOSIT WETH, total collateral value is INITIAL_DEPOSIT * 2000 ETHER / 1e18
        uint256 maxMint = _getMaxMintAmount(alice);
        vm.expectRevert();
        manager.mint(maxMint + 1);
        assertEq(manager.collatRatio(address(alice)), type(uint256).max);

        manager.mint(maxMint);
        assertEq(manager.address2minted(alice), maxMint);
        assertEq(satoshiDollar.balanceOf(alice), maxMint);
    }

    // New function to calculate max mintable amount
    function _getMaxMintAmount(address user) internal view returns (uint256) {
        uint256 userDeposit = manager.address2deposit(user);
        if (userDeposit == 0) return 0;

        // Get current ETH price and scale it to 18 decimals
        uint256 ethPrice = IOracle(oracle).latestAnswer() * 1e10; // Convert from 18 to 8 decimals

        // Calculate total collateral value in USD
        uint256 totalCollateralValue = (userDeposit * ethPrice) / 1e18;

        // Calculate max mintable amount considering minimum collateral ratio
        // maxMint = totalCollateralValue / MIN_COLLAT_RATIO
        uint256 currentlyMinted = manager.address2minted(user);
        uint256 theoreticalMax = (totalCollateralValue * 1e18) / manager.MIN_COLLAT_RATIO();

        // If user has already minted, subtract current minted amount
        if (theoreticalMax <= currentlyMinted) return 0;
        return theoreticalMax - currentlyMinted;
    }

    function test_burn() public {
        // Set initial ETH price to $2000 (2000 ether, representation 18 decimals)
        vm.mockCall(oracle, abi.encodeWithSelector(IOracle.latestAnswer.selector), abi.encode(2000 ether));

        vm.startPrank(alice);
        manager.deposit(INITIAL_DEPOSIT);

        // user deposit INITIAL_DEPOSIT WETH, total collateral value is INITIAL_DEPOSIT * 2000 ETHER / 1e18
        uint256 maxMint = _getMaxMintAmount(alice);
        manager.mint(maxMint);

        uint256 burned = 5000 ether;
        manager.burn(burned);
        assertEq(manager.address2minted(alice), maxMint - burned);
        assertEq(satoshiDollar.balanceOf(alice), maxMint - burned);
    }

    function test_withdraw() public {
        deal(address(weth), bob, 5 ether);

        vm.startPrank(bob);
        manager.deposit(5 ether);

        assertEq(manager.address2deposit(bob), 5 ether);
        assertEq(weth.balanceOf(address(manager)), 5 ether);

        manager.withdraw(5 ether);

        assertEq(manager.address2deposit(bob), 0);
        assertEq(weth.balanceOf(address(manager)), 0);
        assertEq(weth.balanceOf(bob), 5 ether);
    }

    // Liquidation tests
    function test_fullLiquidation() public {
        // Setup underwater position
        vm.startPrank(alice);
        manager.deposit(INITIAL_DEPOSIT);

        uint256 mintAmount = _getMaxMintAmount(alice);
        manager.mint(mintAmount);
        vm.stopPrank();

        // Drop ETH price to make position liquidatable
        // $2000 - 1 wei per ETH
        assertFalse(manager.isUnderwater(alice), "Position should not be underwater");
        vm.mockCall(oracle, abi.encodeWithSelector(IOracle.latestAnswer.selector), abi.encode(2000e8 - 1));
        assertTrue(manager.isUnderwater(alice), "Position should be underwater");

        uint256 bobInitialWeth = weth.balanceOf(bob);
        uint256 bobInitialsatoshiDollar = satoshiDollar.balanceOf(bob);

        // Bob liquidates Alice
        vm.startPrank(bob);
        satoshiDollar.approve(address(manager), type(uint256).max);
        deal(address(satoshiDollar), bob, mintAmount);
        manager.liquidate(alice);

        // Verify liquidation results
        assertEq(manager.address2deposit(alice), 0);
        assertEq(manager.address2minted(alice), 0);
        assertGt(weth.balanceOf(bob), bobInitialWeth);
        assertLt(satoshiDollar.balanceOf(bob), bobInitialsatoshiDollar + INITIAL_MINT);
    }

    function test_partialLiquidation() public {
        // Setup underwater position
        vm.startPrank(alice);
        manager.deposit(INITIAL_DEPOSIT);
        manager.mint(INITIAL_MINT);
        vm.stopPrank();

        uint256 liquidationAmount = INITIAL_MINT / 2;

        vm.startPrank(bob);
        deal(address(satoshiDollar), bob, liquidationAmount);
        satoshiDollar.approve(address(manager), type(uint256).max);

        vm.mockCall(oracle, abi.encodeWithSelector(IOracle.latestAnswer.selector), abi.encode(1000e8 - 1));

        vm.expectEmit(true, true, false, true);
        emit PartialLiquidation(alice, bob, liquidationAmount, 5.25 ether); // Expected collateral with 5% bonus
        manager.liquidate(alice, liquidationAmount);

        assertEq(manager.address2minted(alice), INITIAL_MINT - liquidationAmount);
        assertApproxEqRel(manager.address2deposit(alice), 4.75 ether, 0.01e18); // Remaining collateral
    }

    // Revert tests
    function test_revert_mintWithoutCollateral() public {
        vm.startPrank(alice);
        vm.expectRevert();
        manager.mint(1000e18);
    }

    function test_revert_withdrawTooMuch() public {
        vm.startPrank(alice);
        manager.deposit(INITIAL_DEPOSIT);
        manager.mint(INITIAL_MINT);
        vm.expectRevert();
        manager.withdraw(INITIAL_DEPOSIT);
    }

    function test_revert_liquidateHealthyPosition() public {
        vm.startPrank(alice);
        manager.deposit(INITIAL_DEPOSIT);
        manager.mint(INITIAL_MINT);
        vm.stopPrank();

        vm.startPrank(bob);
        deal(address(satoshiDollar), bob, INITIAL_MINT);
        vm.expectRevert("Position is healthy");
        manager.liquidate(alice, INITIAL_MINT);
    }

    // Fuzz tests
    function testFuzz_deposit(uint256 amount) public {
        // Bound amount to reasonable values
        amount = bound(amount, 0.1 ether, 1000 ether);

        deal(address(weth), bob, amount);

        vm.startPrank(bob);
        manager.deposit(amount);
        assertEq(manager.address2deposit(bob), amount);
    }

    function testFuzz_mintAndBurn(uint256 depositAmount, uint256 mintAmount) public {
        // Bound inputs to reasonable values
        depositAmount = bound(depositAmount, 1 ether, 1000 ether);
        mintAmount = bound(mintAmount, 100e18, depositAmount * 1000); // Keep within collateral ratio

        deal(address(weth), bob, depositAmount);

        vm.startPrank(bob);
        manager.deposit(depositAmount);
        manager.mint(mintAmount);

        assertEq(manager.address2minted(bob), mintAmount);
        assertEq(satoshiDollar.balanceOf(bob), mintAmount);
    }
}
