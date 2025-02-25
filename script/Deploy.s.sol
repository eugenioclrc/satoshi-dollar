// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Manager, SatoshiDollar, IOracle} from "../src/MicroStable.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address WBTC = vm.envOr("WBTC", 0xb4255533Ad74A25A83d17154cB48A287E8f6A811);
        // https://data.chain.link/feeds/ethereum/mainnet/btc-usd
        address oracle = vm.envOr("oracle", 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c);
        SatoshiDollar satoshiDollar = new SatoshiDollar();
        Manager manager = new Manager(address(WBTC), address(satoshiDollar), oracle);
        satoshiDollar.transferOwnership(address(manager));
        vm.stopBroadcast();
    }
}
